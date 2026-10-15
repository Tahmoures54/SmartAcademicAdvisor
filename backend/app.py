"""Small server-side proxy for educational-advice model requests.

Secrets must be supplied through environment variables, never committed to source
or embedded in the Android application.
"""
from __future__ import annotations

import json
import os
import time
from collections import defaultdict, deque
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from flask import Flask, jsonify, request

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024

_rate_buckets: dict[str, deque[float]] = defaultdict(deque)
_ALLOWED_STAGES = {
    "ابتدایی", "متوسطه اول", "متوسطه دوم", "کنکوری", "دانشجو", "فارغ‌التحصیل"
}
_ALLOWED_GOALS = {
    "برنامه‌ریزی درسی", "انتخاب رشته", "آزمون و کنکور", "دانشگاه و شغل"
}


def _is_rate_limited(client_key: str) -> bool:
    """Basic per-process throttle; production deployments need shared rate limiting."""
    try:
        minute_limit = max(1, int(os.getenv("MAX_REQUESTS_PER_MINUTE", "10")))
        daily_limit = max(1, int(os.getenv("MAX_REQUESTS_PER_DAY", "50")))
    except ValueError:
        minute_limit, daily_limit = 10, 50
    now = time.monotonic()
    bucket = _rate_buckets[client_key]
    while bucket and now - bucket[0] >= 24 * 60 * 60:
        bucket.popleft()
    if len(bucket) >= daily_limit:
        return True
    if sum(now - stamp < 60 for stamp in bucket) >= minute_limit:
        return True
    bucket.append(now)
    return False


def _chat_completions_url(base_url: str) -> str:
    value = base_url.rstrip("/")
    if value.endswith("/chat/completions"):
        return value
    return value + "/chat/completions"


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.post("/api/advice")
def advice():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Invalid JSON body"}), 400

    stage = payload.get("stage")
    goal = payload.get("goal")
    question = payload.get("question")
    if stage not in _ALLOWED_STAGES or goal not in _ALLOWED_GOALS:
        return jsonify({"error": "Choose a valid study stage and topic"}), 400
    if not isinstance(question, str) or not question.strip() or len(question) > 1500:
        return jsonify({"error": "Question must contain 1 to 1500 characters"}), 400

    # Do not trust caller-supplied X-Forwarded-For unless a trusted proxy is configured.
    client_key = (request.remote_addr or "unknown")[:80]
    if _is_rate_limited(client_key):
        return jsonify({"error": "Too many requests. Please try again shortly."}), 429

    api_key = os.getenv("AI_API_KEY", "").strip()
    if not api_key:
        return jsonify({"error": "AI service is not configured on the server"}), 503

    base_url = os.getenv("AI_BASE_URL", "https://api.deepseek.com").strip()
    model = os.getenv("AI_MODEL", "deepseek-chat").strip()
    if not base_url or not model:
        return jsonify({"error": "AI provider configuration is incomplete"}), 503

    system_prompt = (
        "تو یک راهنمای آموزشی فارسی‌زبان، محترمانه و محتاط هستی. پاسخ را متناسب با مقطع "
        "دانش‌آموز تنظیم کن. راهکارهای کوتاه، عملی و واقع‌بینانه بده؛ برای کودکان زبان ساده "
        "به‌کار ببر. اطلاعات ساختگی دربارهٔ قوانین پذیرش یا ظرفیت دانشگاه‌ها ارائه نکن. "
        "در انتخاب رشته یا تصمیم‌های مهم، علاقه، توانایی، شرایط فرد و گفت‌وگو با خانواده یا "
        "مشاور مدرسه را یادآوری کن. نتیجه را تضمین نکن و تشخیص پزشکی یا روان‌شناختی نده. "
        "اگر اطلاعات کافی نیست، حداکثر دو سؤال روشن‌کننده بپرس."
    )
    user_prompt = (
        f"مقطع تحصیلی: {stage}\nموضوع: {goal}\nپرسش دانش‌آموز یا کاربر: {question.strip()}\n"
        "پاسخ را به فارسی و با چند گام قابل اجرا ارائه کن."
    )
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.4,
        "max_tokens": 700,
        "stream": False,
    }).encode("utf-8")
    outbound = Request(
        _chat_completions_url(base_url),
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(outbound, timeout=30) as response:
            result = json.loads(response.read().decode("utf-8"))
        answer_text = result["choices"][0]["message"]["content"]
        if not isinstance(answer_text, str) or not answer_text.strip():
            raise ValueError("Empty model response")
    except HTTPError as exc:
        # Do not return upstream response bodies, which may contain provider details.
        app.logger.warning("AI provider returned HTTP %s", exc.code)
        status = 429 if exc.code == 429 else 502
        return jsonify({"error": "AI provider could not complete the request"}), status
    except (URLError, TimeoutError, OSError, ValueError, KeyError, IndexError, TypeError):
        app.logger.warning("AI provider request failed")
        return jsonify({"error": "AI provider is temporarily unavailable"}), 502

    return jsonify({"answer": answer_text.strip()})


@app.errorhandler(413)
def request_too_large(_error):
    return jsonify({"error": "Request body is too large"}), 413


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")), debug=False)
