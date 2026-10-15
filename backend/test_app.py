import json
import os
import unittest
from unittest.mock import patch

from app import app, _rate_buckets


class AdviceApiTests(unittest.TestCase):
    def setUp(self):
        app.config.update(TESTING=True)
        self.client = app.test_client()
        _rate_buckets.clear()
        self.env = patch.dict(os.environ, {}, clear=False)
        self.env.start()
        os.environ.pop("AI_API_KEY", None)

    def tearDown(self):
        self.env.stop()

    def payload(self):
        return {
            "stage": "متوسطه اول",
            "goal": "برنامه‌ریزی درسی",
            "question": "برای امتحان هفته آینده چطور برنامه‌ریزی کنم؟",
        }

    def test_health_endpoint(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})

    def test_rejects_invalid_stage(self):
        payload = self.payload()
        payload["stage"] = "مرحله نامعتبر"
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_rejects_oversized_question(self):
        payload = self.payload()
        payload["question"] = "x" * 1501
        response = self.client.post("/api/advice", json=payload)
        self.assertEqual(response.status_code, 400)

    def test_requires_server_side_api_key(self):
        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("key", response.get_json().get("error", "").lower())

    @patch("app.urlopen")
    def test_returns_provider_answer(self, mocked_urlopen):
        os.environ["AI_API_KEY"] = "test-only-key"
        os.environ["AI_BASE_URL"] = "https://example.invalid/v1"
        os.environ["AI_MODEL"] = "test-model"
        fake_response = unittest.mock.MagicMock()
        fake_response.__enter__.return_value.read.return_value = json.dumps({
            "choices": [{"message": {"content": "ابتدا سه هدف کوچک تعیین کن."}}]
        }).encode("utf-8")
        mocked_urlopen.return_value = fake_response

        response = self.client.post("/api/advice", json=self.payload())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["answer"], "ابتدا سه هدف کوچک تعیین کن.")
        request_sent = mocked_urlopen.call_args.args[0]
        self.assertEqual(request_sent.full_url, "https://example.invalid/v1/chat/completions")
        self.assertEqual(request_sent.get_header("Authorization"), "Bearer test-only-key")


if __name__ == "__main__":
    unittest.main()
