# Educational advice API

The Flask service is the only component that holds the AI provider credential. The Flutter client never receives or embeds the provider key. AI advice is available only through this HTTPS backend; without a configured backend, the app uses offline guidance.

- FastAPI-free, single-file Flask app (`app.py`)
- All configuration via environment variables (no secrets in source)
- Per-IP rate limiting, request validation, security headers, CORS, optional
  retries with backoff, and structured request tracing (`X-Request-ID`)
- Regression tests for validation, readiness, provider failures, and security boundaries (`test_app.py`)

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
cp .env.example .env
# edit .env and set AI_API_KEY to a real provider key; never commit it

# 4. Export the variables (POSIX shells)
set -a && source .env && set +a

# 5. Run
python app.py
# or, for production-style multi-worker:
gunicorn app:app --bind "${HOST:-0.0.0.0}:${PORT:-8000}" --workers 2
