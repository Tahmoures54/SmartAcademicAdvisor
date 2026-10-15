# Educational advice API

This is an optional server-side proxy for an OpenAI-compatible chat-completions API. The Flutter app must never contain the provider API key.

## Run locally

1. Use Python 3.11 or newer.
2. Install dependencies: `pip install -r backend/requirements.txt`
3. Set `AI_API_KEY` in your shell or hosting environment. Never commit a real key.
4. Configure `AI_BASE_URL` and `AI_MODEL` for the chosen compatible provider.
5. Start from this directory with `python app.py`, or use `gunicorn app:app --bind 0.0.0.0:$PORT`.

The `/health` endpoint is a basic health check. Send JSON to `POST /api/advice` with `stage`, `goal`, and `question`.

## Before production

- Set provider spending limits and alerts. The default in-process throttle is 10 requests/minute and 50/day per IP; it is only a basic safeguard, resets on restart, and is not shared across multiple workers.
- Configure HTTPS, trusted reverse-proxy handling, persistent/shared rate limiting, monitoring, and appropriate retention policies at the hosting layer.
- Do not log questions or secrets. Do not expose the API key to the mobile app.
- Keep the service URL in the Flutter build configuration using `--dart-define=ADVISOR_API_BASE_URL=https://your-api.example`.
- Review privacy and child-safety requirements before collecting or transmitting data from minors.

If `AI_API_KEY` is absent, the endpoint returns HTTP 503 without making an upstream request.
