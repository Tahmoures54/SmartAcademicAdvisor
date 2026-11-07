"""Small server-side proxy for educational-advice model requests.

Secrets must be supplied through environment variables, never committed to source
or embedded in the Android application.

Environment variables (all optional except AI_API_KEY for live AI):
    AI_API_KEY               Provider key (empty => /api/advice returns 503)
    AI_BASE_URL              OpenAI-compatible base URL (default: https://api.deepseek.com)
    AI_MODEL                 Model name (default: deepseek-chat)
    AI_TIMEOUT_SECONDS       Upstream request timeout (default: 30)
    AI_MAX_RETRIES           Retries on transient upstream failures (default: 0)
    AI_TEMPERATURE           Sampling temperature (default: 0.4)
    AI_MAX_TOKENS            Max completion tokens (default: 700)
    AI_MAX_ANSWER_CHARS      Cap on returned answer length (default: 8000)
    MAX_QUESTION_LENGTH      Max user question length (default: 1500)
    MAX_BODY_BYTES           Max HTTP body size (default: 16384)
    MAX_REQUESTS_PER_MINUTE  Per-IP limit (default: 10)
    MAX_REQUESTS_PER_DAY     Per-IP daily limit (default: 50)
    TRUST_PROXY              Trust X-Forwarded-For (default: false)
    ALLOWED_ORIGINS          Comma-separated CORS origins (default: disabled)
    HOST                     Bind address (default: 0.0.0.0)
    PORT                     Bind port (default: 8000)
    DEBUG                    Flask debug (default: false)
    LOG_LEVEL                Logging level (default: INFO)
"""
from __future__ import annotations

import json
import logging
import os
import threading
import time
import uuid
from collections import defaultdict, deque
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from flask import Flask, g, jsonify, request


# ── Environment helpers ──────────────────────────────────────────────
def _env_str(key: str, default: str = "") -> str:
    return os.getenv(key, default).strip()


def _env_int(key: str, default: int, minimum: int = 0, maximum: int | None = None) -> int:
    try:
        value = int(os.getenv(key, str(default)))
    except (TypeError, ValueError):
        return default
    if value < minimum:
        return minimum
    if maximum is not None and value > maximum:
        return maximum
    return value


def _env_bool(key: str, default: bool = False) -> bool:
    return os.getenv(key, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def _env_float(key: str, default: float, minimum: float = 0.0, maximum: float = 2.0) -> float:
    try:
        value = float(os.getenv(key, str(default)))
    except (TypeError, ValueError):
        return default
    return max(minimum, min(maximum, value))


# ── Logging ──────────────────────────────────────────────────────────
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper() or "INFO",
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)


# ── Flask app ────────────────────────────────────────────────────────
app = Flask(__name__)

# Persian text should not be escaped to \uXXXX in JSON responses.
_provider = getattr(app, "json", None)
if _provider is not None and hasattr(_provider, "ensure_ascii"):
    _provider.ensure_ascii = False  # Flask 2.2+
else:  # pragma: no cover - legacy Flask
    app.config["JSON_AS_ASCII"] = False

app.config["MAX_CONTENT_LENGTH"] = _env_int("MAX_BODY_BYTES", 16 * 1024, minimum=1)


# ── Rate limiter (per-process, best-effort) ──────────────────────────
_rate_buckets: dict[str, deque[float]] = defaultdict(deque)
_rate_lock = threading.Lock()
_MAX_BUCKET_KEYS = 10_000


def _is_rate_limited(client_key: str) -> bool:
    """Basic per-process throttle; production deployments need shared rate limiting."""
    minute_limit = _env_int("MAX_REQUESTS_PER_MINUTE", 10, minimum=1)
    daily_limit = _env_int("MAX_REQUESTS_PER_DAY", 50, minimum=1)
    now = time.monotonic()
    day_window = 24 * 60 * 60
    with _rate_lock:
        bucket = _rate_buckets[client_key]
        while bucket and now - bucket[0] >= day_window:
            bucket.popleft()
        if len(bucket) >= daily_limit:
            return True
        if sum(now - stamp < 60 for stamp in bucket) >= minute_limit:
            return True
        bucket.append(now)
        # Lazy cleanup to bound memory if many distinct clients hit us.
        if len(_rate_buckets) > _MAX_BUCKET_KEYS:
            for key in [k for k, v in _rate_buckets.items() if not v]:
                _rate_buckets.pop(key, None)
        return False


# ── Constants ────────────────────────────────────────────────────────
_ALLOWED_STAGES = {
    "ابتدایی", "متوسطه اول", "متوسطه دوم", "کنکوری", "دانشجو", "فارغ‌التحصیل"
}
_ALLOWED_GOALS = {
    "برنامه‌ریزی درسی", "انتخاب رشته", "آزمون و کنکور", "دانشگاه و شغل"
}
_SYSTEM_PROMPT = (
    "تو یک راهنمای آموزشی فارسی‌زبان، محترمانه و محتاط هستی. پاسخ را متناسب با مقطع "
    "دانش‌آموز تنظیم کن. راهکارهای کوتاه، عملی و واقع‌بینانه بده؛ برای کودکان زبان ساده "
    "به‌کار ببر. اطلاعات ساختگی دربارهٔ قوانین پذیرش یا ظرفیت دانشگاه‌ها ارائه نکن. "
    "در انتخاب رشته یا تصمیم‌های مهم، علاقه، توانایی، شرایط فرد و گفت‌وگو با خانواده یا "
    "مشاور مدرسه را یادآوری کن. نتیجه را تضمین نکن و تشخیص پزشکی یا روان‌شناختی نده. "
    "اگر اطلاعات کافی نیست، حداکثر دو سؤال روشن‌کننده بپرس."
)


# ── Helpers ──────────────────────────────────────────────────────────
def _chat_completions_url(base_url: str) -> str:
    value = base_url.rstrip("/")
    if value.endswith("/chat/completions"):
        return value
    return value + "/chat/completions"


def _error(message: str, status: int, headers: dict[str, str] | None = None):
    response = jsonify({"error": message})
    if headers:
        for header_name, header_value in headers.items():
            response.headers[header_name] = header_value
    return response, status


def _client_ip() -> str:
    if _env_bool("TRUST_PROXY", False):
        forwarded = request.headers.get("X-Forwarded-For", "")
        if forwarded:
            # First hop is the client when behind a trusted proxy.
            return (forwarded.split(",")[0].strip() or "unknown")[:80]
    return (request.remote_addr or "unknown")[:80]


def _upstream_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": (
            "SmartAcademicAdvisor/1.1 "
            "(+https://github.com/Tahmoures54/SmartAcademicAdvisor)"
        ),
    }


def _call_upstream(
    url: str, body: bytes, headers: dict[str, str], timeout: int, retries: int
):
    """POST to the upstream endpoint, retrying transient failures only."""
    last_exc: BaseException | None = None
    for attempt in range(retries + 1):
        try:
            outbound = Request(url, data=body, headers=headers, method="POST")
            with urlopen(outbound, timeout=timeout) as response:
                max_bytes = _env_int("MAX_UPSTREAM_RESPONSE_BYTES", 1_048_576, minimum=1024, maximum=5_242_880)
                raw = response.read(max_bytes + 1)
                if len(raw) > max_bytes:
                    raise ValueError("Provider response exceeded the configured size limit")
                return json.loads(raw.decode("utf-8"))
        except HTTPError as exc:
            # Retry 5xx only; 4xx are caller/config errors and will not recover.
            if 500 <= exc.code < 600 and attempt < retries:
                last_exc = exc
                time.sleep(0.4 * (attempt + 1))
                continue
            raise
        except (URLError, TimeoutError, OSError) as exc:
            if attempt < retries:
                last_exc = exc
                time.sleep(0.4 * (attempt + 1))
                continue
            raise
    if last_exc is not None:
        raise last_exc
    raise RuntimeError("upstream call failed without an exception")


# ── Request lifecycle ────────────────────────────────────────────────
@app.before_request
def _setup_request_id() -> None:
    g.request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex[:12]


@app.after_request
def _apply_common_headers(response):
    # Security headers.
    response.headers.setdefault("Cache-Control", "no-store")
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("X-Request-ID", g.get("request_id", ""))

    # CORS — only when explicitly configured.
    allowed = _env_str("ALLOWED_ORIGINS", "")
    if allowed:
        origins = [o.strip() for o in allowed.split(",") if o.strip()]
        origin = request.headers.get("Origin", "")
        if "*" in origins:
            response.headers["Access-Control-Allow-Origin"] = "*"
        elif origin and origin in origins:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
        response.headers.setdefault("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        response.headers.setdefault(
            "Access-Control-Allow-Headers", "Content-Type, X-Request-ID"
        )
        response.headers.setdefault("Access-Control-Max-Age", "600")
    return response


# ── Routes ───────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/ready")
def ready():
    """Readiness probe: report ready only when a valid provider is configured."""
    api_key = _env_str("AI_API_KEY", "")
    base_url = _env_str("AI_BASE_URL", "https://api.deepseek.com")
    model = _env_str("AI_MODEL", "deepseek-chat")
    parsed = urlsplit(_chat_completions_url(base_url)) if base_url else None
    configured = bool(api_key and model and parsed and parsed.scheme == "https" and parsed.netloc)
    return jsonify({"status": "ready" if configured else "not_ready"}), 200 if configured else 503


@app.route("/api/advice", methods=["OPTIONS"])
def advice_options():
    # CORS preflight; actual headers are added by `_apply_common_headers`.
    return ("", 204)


@app.post("/api/advice")
def advice():
    if not request.is_json:
        return _error("Content-Type must be application/json", 415)

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return _error("Invalid JSON body", 400)

    stage = payload.get("stage")
    goal = payload.get("goal")
    question = payload.get("question")
    if (
        not isinstance(stage, str)
        or not isinstance(goal, str)
        or stage not in _ALLOWED_STAGES
        or goal not in _ALLOWED_GOALS
    ):
        return _error("Choose a valid study stage and topic", 400)

    max_question = _env_int("MAX_QUESTION_LENGTH", 1500, minimum=1)
    if not isinstance(question, str) or not question.strip() or len(question) > max_question:
        return _error(f"Question must contain 1 to {max_question} characters", 400)
    question = question.strip()

    client_key = _client_ip()
    if _is_rate_limited(client_key):
        app.logger.warning(
            "rate limit hit ip=%s request_id=%s",
            client_key, g.get("request_id"),
        )
        return _error(
            "Too many requests. Please try again shortly.",
            429,
            headers={"Retry-After": "60"},
        )

    api_key = _env_str("AI_API_KEY", "")
    if not api_key:
        return _error("AI service is not configured on the server", 503)

    base_url = _env_str("AI_BASE_URL", "https://api.deepseek.com")
    model = _env_str("AI_MODEL", "deepseek-chat")
    if not base_url or not model:
        return _error("AI provider configuration is incomplete", 503)
    parsed_provider_url = urlsplit(_chat_completions_url(base_url))
    if parsed_provider_url.scheme != "https" or not parsed_provider_url.netloc:
        return _error("AI provider URL must use HTTPS", 503)

    timeout = _env_int("AI_TIMEOUT_SECONDS", 30, minimum=1)
    retries = _env_int("AI_MAX_RETRIES", 0, minimum=0, maximum=5)
    temperature = _env_float("AI_TEMPERATURE", 0.4, minimum=0.0, maximum=2.0)
    max_tokens = _env_int("AI_MAX_TOKENS", 700, minimum=1, maximum=8000)
    max_answer_chars = _env_int("AI_MAX_ANSWER_CHARS", 8000, minimum=100)

    user_prompt = (
        f"مقطع تحصیلی: {stage}\nموضوع: {goal}\nپرسش دانش‌آموز یا کاربر: {question}\n"
        "پاسخ را به فارسی و با چند گام قابل اجرا ارائه کن."
    )
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": False,
    }).encode("utf-8")

    try:
        result = _call_upstream(
            _chat_completions_url(base_url),
            body,
            _upstream_headers(api_key),
            timeout,
            retries,
        )
        answer_text = result["choices"][0]["message"]["content"]
        if not isinstance(answer_text, str) or not answer_text.strip():
            raise ValueError("Empty model response")
    except HTTPError as exc:
        # Do not return upstream response bodies, which may contain provider details.
        app.logger.warning(
            "AI provider returned HTTP %s ip=%s request_id=%s",
            exc.code, client_key, g.get("request_id"),
        )
        status = 429 if exc.code == 429 else 502
        return _error("AI provider could not complete the request", status)
    except (
        URLError, TimeoutError, OSError, ValueError, KeyError, IndexError, TypeError
    ) as exc:
        app.logger.warning(
            "AI provider request failed (%s) ip=%s request_id=%s",
            type(exc).__name__, client_key, g.get("request_id"),
        )
        return _error("AI provider is temporarily unavailable", 502)

    answer_text = answer_text.strip()
    if len(answer_text) > max_answer_chars:
        answer_text = answer_text[: max_answer_chars - 1].rstrip() + "…"

    app.logger.info(
        "advice ok ip=%s request_id=%s chars=%d",
        client_key, g.get("request_id"), len(answer_text),
    )
    return jsonify({"answer": answer_text})


# ── Error handlers ───────────────────────────────────────────────────
@app.errorhandler(413)
def request_too_large(_exc):
    return _error("Request body is too large", 413)


@app.errorhandler(404)
def not_found(_exc):
    return _error("Not found", 404)


@app.errorhandler(405)
def method_not_allowed(_exc):
    return _error("Method not allowed", 405)


@app.errorhandler(500)
def internal_error(_exc):
    return _error("Internal server error", 500)


# ── Startup ──────────────────────────────────────────────────────────
def _warn_if_unconfigured() -> None:
    if not _env_str("AI_API_KEY", ""):
        app.logger.warning(
            "AI_API_KEY is empty — /api/advice will return 503 until configured."
        )


if __name__ == "__main__":
    _warn_if_unconfigured()
    app.run(
        host=_env_str("HOST", "0.0.0.0") or "0.0.0.0",
        port=_env_int("PORT", 8000, minimum=1, maximum=65535),
        debug=_env_bool("DEBUG", False),
    )
