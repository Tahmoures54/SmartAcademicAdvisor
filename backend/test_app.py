import json
import os
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

from app import app, _chat_completions_url, _rate_buckets


class AdviceApiTests(unittest.TestCase):
    # All env vars that can change app behavior; cleared in setUp for isolation.
    ENV_KEYS = (
        "AI_API_KEY",
        "AI_BASE_URL",
        "AI_MODEL",
        "AI_TIMEOUT_SECONDS",
        "AI_MAX_RETRIES",
        "AI_TEMPERATURE",
        "AI_MAX_TOKENS",
        "AI_MAX_ANSWER_CHARS",
        "MAX_QUESTION_LENGTH",
        "MAX_BODY_BYTES",
        "MAX_REQUESTS_PER_MINUTE",
        "MAX_REQUESTS_PER_DAY",
        "TRUST_PROXY",
        "ALLOWED_ORIGINS",
    )

    def setUp(self):
        app.config.update(TESTING=True)
        self.client = app.test_client()
        _rate_buckets.clear()
        # Snapshot env, then scrub every key we care about so a stray CI/host
        # value cannot destabilize this test run.
        self.env = patch.dict(os.environ, {}, clear=False)
        self.env.start()
        for key in self.ENV_KEYS:
            os.environ.pop(key, None)

    def tearDown(self):
        self.env.stop()

    # ── Helpers ──────────────────────────────────────────────────
    def payload(self):
        return {
            "stage": "متوسطه اول",
            "goal": "برنامه‌ریزی درسی",
            "question": "برای امتحان هفته آینده چطور برنامه‌ریزی کنم؟",
        }

    def _configure_provider(self):
        os.environ["AI_API_KEY"] = "test-only-key"
        os.environ["AI_BASE_URL"] = "https://example.invalid/v1"
        os.environ["AI_MODEL"] = "test-model"

    def _mock_success(self, content: str = "ابتدا سه هدف کوچک تعیین کن."):
        fake_response = MagicMock()
        fake_response.__enter__.return_value.read.return_value = json.dumps({
            "choices": [{"message": {"content": content}}]
        }).encode("utf-8")
        return fake_response

    # ── Health / basic ───────────────────────────────────────────
    def test_health_endpoint(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})

    # ── Validation ───────────────────────────────────────────────
    def test_rejects_invalid_stage(self):
        payload = self.payload()
        payload["stage"] = "مرحله نامعتبر"
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_rejects_invalid_goal(self):
        payload = self.payload()
        payload["goal"] = "هدف نامعتبر"
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_rejects_oversized_question(self):
        payload = self.payload()
        payload["question"] = "x" * 1501
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_rejects_whitespace_question(self):
        payload = self.payload()
        payload["question"] = "   \t  "
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_rejects_non_string_question(self):
        payload = self.payload()
        payload["question"] = 12345
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_rejects_non_json_content_type(self):
        response = self.client.post(
            "/api/advice", data="not json", content_type="text/plain"
        )
        self.assertEqual(response.status_code, 415)
        self.assertIsNotNone(response.get_json())

    def test_rejects_invalid_json_body(self):
        response = self.client.post(
            "/api/advice", data="{not json", content_type="application/json"
        )
        self.assertEqual(response.status_code, 400)

    def test_max_question_length_env_override(self):
        os.environ["MAX_QUESTION_LENGTH"] = "5"
        payload = self.payload()
        payload["question"] = "123456"  # 6 chars > 5
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_oversized_body_rejected(self):
        original = app.config["MAX_CONTENT_LENGTH"]
        app.config["MAX_CONTENT_LENGTH"] = 1024
        try:
            response = self.client.post(
                "/api/advice",
                data="x" * 4096,
                content_type="application/json",
            )
            self.assertEqual(response.status_code, 413)
            self.assertIsNotNone(response.get_json())
        finally:
            app.config["MAX_CONTENT_LENGTH"] = original

    # ── API key / provider config ────────────────────────────────
    def test_requires_server_side_api_key(self):
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("key", response.get_json().get("error", "").lower())

    def test_requires_base_url(self):
        self._configure_provider()
        os.environ["AI_BASE_URL"] = ""
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 503)

    def test_requires_model(self):
        self._configure_provider()
        os.environ["AI_MODEL"] = ""
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 503)

    # ── Rate limiting ────────────────────────────────────────────
    def test_enforces_daily_request_limit(self):
        os.environ["MAX_REQUESTS_PER_DAY"] = "1"
        first = self.client.post("/api/advice", json=self.payload())
        second = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(first.status_code, 503)
        self.assertEqual(second.status_code, 429)

    def test_enforces_minute_request_limit(self):
        os.environ["MAX_REQUESTS_PER_MINUTE"] = "1"
        os.environ["MAX_REQUESTS_PER_DAY"] = "10"
        first = self.client.post("/api/advice", json=self.payload())
        second = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(first.status_code, 503)
        self.assertEqual(second.status_code, 429)

    def test_rate_limit_returns_retry_after(self):
        os.environ["MAX_REQUESTS_PER_DAY"] = "1"
        self.client.post("/api/advice", json=self.payload())
        second = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(second.status_code, 429)
        self.assertEqual(second.headers.get("Retry-After"), "60")

    # ── Provider success path ────────────────────────────────────
    @patch("app.urlopen")
    def test_returns_provider_answer(self, mocked_urlopen):
        self._configure_provider()
        mocked_urlopen.return_value = self._mock_success()

        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["answer"], "ابتدا سه هدف کوچک تعیین کن.")

        request_sent = mocked_urlopen.call_args.args[0]
        self.assertEqual(
            request_sent.full_url, "https://example.invalid/v1/chat/completions"
        )
        self.assertEqual(
            request_sent.get_header("Authorization"), "Bearer test-only-key"
        )

    @patch("app.urlopen")
    def test_persian_text_not_escaped(self, mocked_urlopen):
        self._configure_provider()
        mocked_urlopen.return_value = self._mock_success("سلام دنیا")

        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 200)
        # Persian must be raw UTF-8, not \u06XX escapes.
        self.assertNotIn(b"\\u06", response.data)
        self.assertIn("سلام دنیا".encode("utf-8"), response.data)

    @patch("app.urlopen")
    def test_truncates_oversized_answer(self, mocked_urlopen):
        self._configure_provider()
        os.environ["AI_MAX_ANSWER_CHARS"] = "10"
        mocked_urlopen.return_value = self._mock_success("a" * 100)

        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 200)
        self.assertLessEqual(len(response.get_json()["answer"]), 10)

    @patch("app.urlopen")
    def test_timeout_passed_to_urlopen(self, mocked_urlopen):
        self._configure_provider()
        os.environ["AI_TIMEOUT_SECONDS"] = "7"
        mocked_urlopen.return_value = self._mock_success()

        self.client.post("/api/advice", json=self.payload())
        self.assertEqual(mocked_urlopen.call_args.kwargs.get("timeout"), 7)

    # ── Provider error paths ─────────────────────────────────────
    @patch("app.urlopen")
    def test_provider_429_maps_to_429(self, mocked_urlopen):
        self._configure_provider()
        mocked_urlopen.side_effect = HTTPError("url", 429, "Too Many", {}, None)
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 429)

    @patch("app.urlopen")
    def test_provider_5xx_maps_to_502(self, mocked_urlopen):
        self._configure_provider()
        mocked_urlopen.side_effect = HTTPError("url", 500, "Server Error", {}, None)
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 502)

    @patch("app.urlopen")
    def test_provider_unreachable_maps_to_502(self, mocked_urlopen):
        self._configure_provider()
        mocked_urlopen.side_effect = URLError("network down")
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 502)

    @patch("app.urlopen")
    def test_provider_empty_response_maps_to_502(self, mocked_urlopen):
        self._configure_provider()
        mocked_urlopen.return_value = self._mock_success("   ")
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 502)

    @patch("app.time.sleep")
    @patch("app.urlopen")
    def test_retries_on_transient_error(self, mocked_urlopen, _mocked_sleep):
        self._configure_provider()
        os.environ["AI_MAX_RETRIES"] = "1"
        transient = HTTPError("url", 503, "Unavailable", {}, None)
        mocked_urlopen.side_effect = [transient, self._mock_success()]

        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(mocked_urlopen.call_count, 2)

    @patch("app.time.sleep")
    @patch("app.urlopen")
    def test_does_not_retry_on_4xx(self, mocked_urlopen, _mocked_sleep):
        self._configure_provider()
        os.environ["AI_MAX_RETRIES"] = "3"
        mocked_urlopen.side_effect = HTTPError("url", 401, "Unauthorized", {}, None)

        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 502)
        self.assertEqual(mocked_urlopen.call_count, 1)

    # ── Proxy / client IP ────────────────────────────────────────
    def test_forwarded_for_ignored_by_default(self):
        os.environ["MAX_REQUESTS_PER_DAY"] = "1"
        first = self.client.post(
            "/api/advice",
            json=self.payload(),
            headers={"X-Forwarded-For": "1.1.1.1"},
        )
        second = self.client.post(
            "/api/advice",
            json=self.payload(),
            headers={"X-Forwarded-For": "2.2.2.2"},
        )
        # Same remote_addr (test client), so daily limit catches the second.
        self.assertEqual(first.status_code, 503)
        self.assertEqual(second.status_code, 429)

    def test_forwarded_for_used_when_trust_proxy(self):
        os.environ["TRUST_PROXY"] = "true"
        os.environ["MAX_REQUESTS_PER_DAY"] = "1"
        first = self.client.post(
            "/api/advice",
            json=self.payload(),
            headers={"X-Forwarded-For": "1.1.1.1"},
        )
        second = self.client.post(
            "/api/advice",
            json=self.payload(),
            headers={"X-Forwarded-For": "2.2.2.2"},
        )
        # Different XFF first hops => separate buckets => neither limited.
        self.assertEqual(first.status_code, 503)
        self.assertEqual(second.status_code, 503)

    # ── Headers / CORS ───────────────────────────────────────────
    def test_request_id_header_present(self):
        response = self.client.get("/health")
        self.assertIn("X-Request-ID", response.headers)
        self.assertTrue(response.headers["X-Request-ID"])

    def test_request_id_echoed_from_client(self):
        response = self.client.get(
            "/health", headers={"X-Request-ID": "my-trace-id"}
        )
        self.assertEqual(response.headers["X-Request-ID"], "my-trace-id")

    def test_security_headers_present(self):
        response = self.client.get("/health")
        self.assertEqual(response.headers.get("X-Content-Type-Options"), "nosniff")
        self.assertEqual(response.headers.get("X-Frame-Options"), "DENY")
        self.assertEqual(response.headers.get("Referrer-Policy"), "no-referrer")

    def test_cors_disabled_by_default(self):
        response = self.client.get("/health")
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)

    def test_cors_allows_configured_origin(self):
        os.environ["ALLOWED_ORIGINS"] = "https://app.example.com"
        response = self.client.get(
            "/health", headers={"Origin": "https://app.example.com"}
        )
        self.assertEqual(
            response.headers.get("Access-Control-Allow-Origin"),
            "https://app.example.com",
        )

    def test_cors_rejects_unlisted_origin(self):
        os.environ["ALLOWED_ORIGINS"] = "https://app.example.com"
        response = self.client.get(
            "/health", headers={"Origin": "https://evil.example.com"}
        )
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)

    def test_cors_wildcard(self):
        os.environ["ALLOWED_ORIGINS"] = "*"
        response = self.client.get(
            "/health", headers={"Origin": "https://anywhere.example.com"}
        )
        self.assertEqual(
            response.headers.get("Access-Control-Allow-Origin"), "*"
        )

    def test_options_preflight(self):
        os.environ["ALLOWED_ORIGINS"] = "*"
        response = self.client.options(
            "/api/advice",
            headers={
                "Origin": "https://example.com",
                "Access-Control-Request-Method": "POST",
            },
        )
        # 200 (Flask auto-OPTIONS) or 204 (custom handler) — both valid.
        self.assertIn(response.status_code, (200, 204))
        self.assertEqual(
            response.headers.get("Access-Control-Allow-Origin"), "*"
        )

    # ── 404 / 405 ────────────────────────────────────────────────
    def test_404_returns_json(self):
        response = self.client.get("/does-not-exist")
        self.assertEqual(response.status_code, 404)
        self.assertIsNotNone(response.get_json())

    def test_405_returns_json(self):
        response = self.client.get("/api/advice")
        self.assertEqual(response.status_code, 405)
        self.assertIsNotNone(response.get_json())

    # ── Helpers ──────────────────────────────────────────────────
    def test_chat_completions_url_helper(self):
        self.assertEqual(
            _chat_completions_url("https://api.example.com"),
            "https://api.example.com/chat/completions",
        )
        self.assertEqual(
            _chat_completions_url("https://api.example.com/"),
            "https://api.example.com/chat/completions",
        )
        self.assertEqual(
            _chat_completions_url("https://api.example.com/v1"),
            "https://api.example.com/v1/chat/completions",
        )
        self.assertEqual(
            _chat_completions_url("https://api.example.com/chat/completions"),
            "https://api.example.com/chat/completions",
        )


if __name__ == "__main__":
    unittest.main()
