# Educational advice API

This Flask service is the only component allowed to hold the AI provider credential. The Android app sends advice requests to this service; it never receives the provider key.

## Run locally

From the repository root:

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt
export AI_API_KEY="your-provider-key"
export AI_BASE_URL="https://api.deepseek.com"
export AI_MODEL="deepseek-chat"
gunicorn --chdir backend --bind 127.0.0.1:8000 --workers 1 --threads 4 app:app
```

On Windows PowerShell, use `$env:AI_API_KEY="..."` for environment variables. Never commit a real key or put it in Flutter build arguments.

## Endpoints

- `GET /health`: liveness check; does not expose configuration.
- `GET /ready`: readiness check; returns 503 unless the server has a key and valid HTTPS provider URL.
- `POST /api/advice`: accepts `stage`, `goal`, and `question`; returns only the answer or a generic error.

The service validates allowed stages/topics, limits question length and request size, requires HTTPS for the upstream provider, bounds upstream response size and timeout, and does not intentionally persist prompts or answers. Responses include no-store and basic security headers.

## Render staging

A Render Blueprint is provided at the repository root in `render.yaml`; its Dockerfile is `backend/Dockerfile`.

1. Connect this repository to Render and create a Blueprint from `render.yaml`.
2. Keep the staging branch selected until the changes have been reviewed and merged.
3. Enter the provider credential only in Render's secret environment-variable field named `AI_API_KEY`.
4. Keep `AI_BASE_URL` and `AI_MODEL` aligned with the provider account.
5. Deploy manually, then check `https://YOUR-SERVICE.onrender.com/health` and `/ready`.
6. Set the resulting HTTPS service URL as GitHub Actions repository variable `ADVISOR_API_BASE_URL` only after the service is verified.

The Blueprint deliberately uses Render's Free plan for a staging/pilot test, not a production guarantee. Free services sleep after 15 minutes without inbound traffic and can take about a minute to wake; the filesystem is ephemeral and instances may restart. The service stores no application data, but the first AI request after sleep may time out. For public release, use an always-on paid service or another production host, set provider-side spending limits, and use shared rate limiting before allowing unrestricted public traffic.

## Rate limiting and abuse controls

The current per-IP throttle is intentionally a single-process pilot safeguard (10 requests/minute and 50/day by default). It is not a substitute for shared rate limiting, user authentication, or provider-side budget caps. Keep one Gunicorn worker for the free pilot, configure hard spending limits and alerts at the AI provider, and do not advertise the public endpoint as abuse-proof. Do not trust forwarded client IP headers except behind the configured hosting proxy.

## Tests

```bash
cd backend
python -m unittest -v test_app.py
```

The backend test suite uses a mocked provider response; it does not require a live API key or incur provider charges.
