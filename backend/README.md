# Educational advice API

Optional server-side proxy in front of any OpenAI-compatible chat-completions
provider. It keeps the provider key off the client device: the Flutter app can
also be built with a key baked in via GitHub Actions (for local testing only),
but any key embedded in an APK is extractable. For public releases, route all
traffic through this proxy.

- FastAPI-free, single-file Flask app (`app.py`)
- All configuration via environment variables (no secrets in source)
- Per-IP rate limiting, request validation, security headers, CORS, optional
  retries with backoff, and structured request tracing (`X-Request-ID`)
- 36 unit tests included (`test_app.py`)

## Contents

- [Quick start](#quick-start)
- [API reference](#api-reference)
- [Configuration](#configuration)
- [Running tests](#running-tests)
- [Production checklist](#production-checklist)
- [Deployment](#deployment)
- [Scaling the rate limiter](#scaling-the-rate-limiter)
- [Flutter integration](#flutter-integration)
- [Troubleshooting](#troubleshooting)
- [Privacy and child-safety](#privacy-and-child-safety)

## Quick start

Requirements: Python 3.11 or newer.

```bash
cd backend

# 1. Isolated environment
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate

# 2. Dependencies
pip install -r requirements.txt

# 3. Configuration (never commit .env)
cp ../.env.example .env            # if you keep .env.example at repo root
# else create backend/.env with the keys listed in "Configuration" below
# then open .env and set AI_API_KEY to a real provider key

# 4. Export the variables (POSIX shells)
set -a && source .env && set +a

# 5. Run
python app.py
# or, for production-style multi-worker:
gunicorn app:app --bind "${HOST:-0.0.0.0}:${PORT:-8000}" --workers 2
