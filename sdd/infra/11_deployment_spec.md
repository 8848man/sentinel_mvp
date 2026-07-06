# 11 — Deployment Specification

**Cloud:** Google Cloud Platform (GCP)  
**Refs:** → [Backend Architecture](../backend/09_backend_arch.md) · [Database Schema](../backend/06_database_schema.md) · [Production Auth](../auth/02_production.md)

---

## Services

| Service | GCP Product | Purpose |
|---------|-------------|---------|
| Backend API | Cloud Run | Containerized FastAPI, auto-scales to zero |
| Frontend | Firebase Hosting | Flutter web build, CDN-served |
| Database | Cloud SQL (PostgreSQL 16) | Managed PostgreSQL, private IP |
| Secrets | Secret Manager | API keys, DB credentials |
| CI/CD | Cloud Build | Automated build + deploy on git push |
| Logs | Cloud Logging | All backend logs |
| Container Registry | Artifact Registry | Docker images |

---

## Backend: Cloud Run

**Region:** `asia-northeast3` (Seoul) — adjust to team location  
**Concurrency:** 80 requests per instance  
**Min instances:** 0 (MVP cost optimization)  
**Max instances:** 10  
**Memory:** 512Mi  
**CPU:** 1 vCPU  
**Port:** 8080

```yaml
# deployment/cloud-run.yaml (used with gcloud run deploy)
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: sentinel-backend
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containers:
        - image: REGION-docker.pkg.dev/PROJECT/sentinel/backend:latest
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: sentinel-db-url, version: latest }
            - name: SUPABASE_URL
              valueFrom:
                secretKeyRef: { name: sentinel-supabase-url, version: latest }
            - name: GEMINI_API_KEY
              valueFrom:
                secretKeyRef: { name: sentinel-gemini-key, version: latest }
          resources:
            limits: { memory: 512Mi, cpu: "1" }
```

---

## Authentication (ES256 / JWKS)

The backend verifies JWTs using Supabase's JWKS endpoint. No shared secret is used.

- **Algorithm:** ES256 (not HS256)
- **Key source:** `{SUPABASE_URL}/auth/v1/.well-known/jwks.json` — fetched at startup via `PyJWKClient`
- **Required env var:** `SUPABASE_URL` — used to derive the JWKS URL at runtime
- **No `SUPABASE_JWT_SECRET`** — this variable does not exist in the backend. Do not provision it.

See [Production Auth](../auth/02_production.md) for the verification implementation.

---

## Backend: Dockerfile

```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "2"]
```

---

## Database: Cloud SQL

- **Engine:** PostgreSQL 16
- **Tier:** `db-f1-micro` (MVP); upgrade to `db-g1-small` at scale
- **Connection:** Via Cloud SQL Auth Proxy (Cloud Run native integration)
- **DATABASE_URL format:** `postgresql+asyncpg://user:pass@/dbname?host=/cloudsql/PROJECT:REGION:INSTANCE`
- **Backups:** Automated daily backups, 7-day retention

**Initial schema setup (PostgreSQL):**
```bash
# Configure DATABASE_URL pointing to Cloud SQL instance, then:
cd backend
alembic upgrade head
```

Migrations are located at `backend/alembic/versions/`. Never run `init_db()` against PostgreSQL — it is for SQLite dev only.

---

## Frontend: Firebase Hosting

**Deployments must go through `scripts/deploy_web.sh` — never invoke `flutter build web` / `firebase deploy` by hand.** The script is the single source of truth for which `--dart-define` flags a deploy needs; hand-typed commands are how `SUPABASE_URL`/`SUPABASE_ANON_KEY` get forgotten and ship an app that initializes Supabase with an empty URL (see [Auth Overview](../auth/00_overview.md) for the failure mode this causes at sign-in).

### Deployment architecture

```
developer / CI runner
       │
       │  SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL (env vars or scripts/.env.<environment>)
       ▼
scripts/deploy_web.sh <production|staging>
       │
       ├── 1. flutter build web --release --dart-define=... (frontend/sentinel)
       └── 2. firebase deploy --only hosting --project <project>
                      │
                      ▼
              Firebase Hosting (CDN) ── frontend/sentinel/firebase.json, .firebaserc
```

### Required environment variables (script inputs)

| Variable | Required for | Purpose |
|----------|--------------|---------|
| `SUPABASE_URL` | `production` | Supabase project URL baked into the build via `--dart-define` |
| `SUPABASE_ANON_KEY` | `production` | Supabase anon key baked into the build via `--dart-define` |
| `API_BASE_URL` | `production` | Backend Cloud Run URL baked into the build via `--dart-define` |
| `FIREBASE_PROJECT` | optional | Overrides the default Firebase project (`sentinel-mvp-eeeee`) |

The script fails immediately with a readable error if a required variable is missing — it never proceeds to `flutter build` with a blank value. Values may also be supplied via a local, gitignored `scripts/.env.production` (or `.env.staging`) file, which the script sources automatically if present.

### Deployment workflow

```bash
# One-time: authenticate the Firebase CLI
firebase login

# Production deploy
SUPABASE_URL=https://<project>.supabase.co \
SUPABASE_ANON_KEY=<anon-key> \
API_BASE_URL=https://sentinel-backend-<hash>-an.a.run.app \
./scripts/deploy_web.sh production
```

`AUTH_PROVIDER=supabase`, `USE_MOCK_DATA=false`, and `SKIP_EMAIL_VERIFICATION=false` are hardcoded into the script's `production` case — a production deploy can never accidentally ship with mock data or the dev auth provider active.

**Staging** is stubbed in the script (`scripts/deploy_web.sh`, `staging` case) and exits with an explanatory error until a staging Supabase project + Cloud Run backend exist. To enable it: provision those resources, then fill in the staging branch (mirrors the `production` case) and set the corresponding variables via `scripts/.env.staging` or CI substitutions.

### CI (Cloud Build)

`deployment/cloudbuild.yaml`'s `frontend-build` step passes the same three "hardening" defines (`AUTH_PROVIDER=supabase`, `USE_MOCK_DATA=false`, `SKIP_EMAIL_VERIFICATION=false`) directly as `flutter build web` args, since Cloud Build steps run in per-tool containers (a `flutter` image, then a separate `firebase` image) and can't invoke the bash script as a single unit the way a local/production deploy can. Keep these two flows in parity by hand if either one's dart-define list changes.

**firebase.json:**
```json
{
  "hosting": {
    "public": "frontend/sentinel/build/web",
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      {
        "source": "**/*.@(js|css|wasm)",
        "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
      }
    ]
  }
}
```

---

## CI/CD: Cloud Build

**File:** `deployment/cloudbuild.yaml`

```yaml
steps:
  # 1. Run backend tests
  - name: 'python:3.12'
    entrypoint: 'bash'
    args: ['-c', 'cd backend && pip install -r requirements.txt && pytest']

  # 2. Build backend Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', '$_REGION-docker.pkg.dev/$PROJECT_ID/sentinel/backend:$COMMIT_SHA', './backend']

  # 3. Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '$_REGION-docker.pkg.dev/$PROJECT_ID/sentinel/backend:$COMMIT_SHA']

  # 4. Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    args:
      - 'run', 'deploy', 'sentinel-backend'
      - '--image', '$_REGION-docker.pkg.dev/$PROJECT_ID/sentinel/backend:$COMMIT_SHA'
      - '--region', '$_REGION'
      - '--platform', 'managed'

  # 5. Build Flutter web
  - name: 'ghcr.io/cirruslabs/flutter:stable'
    args: ['flutter', 'build', 'web', '--release']
    dir: 'frontend/sentinel'

  # 6. Deploy to Firebase Hosting
  - name: 'gcr.io/firebase/firebase:latest'
    args: ['deploy', '--only', 'hosting', '--project', '$PROJECT_ID']

substitutions:
  _REGION: asia-northeast3
```

---

## Environment Variables

### Backend (Secret Manager)

| Variable | Secret Manager name | Purpose |
|----------|--------------------|---------| 
| `DATABASE_URL` | `sentinel-db-url` | PostgreSQL connection string (required in prod) |
| `SUPABASE_URL` | `sentinel-supabase-url` | Supabase project URL; used to derive JWKS endpoint |
| `GEMINI_API_KEY` | `sentinel-gemini-key` | Gemini API authentication |

### Backend (optional env vars, set directly on Cloud Run service)

| Variable | Default | Purpose |
|----------|---------|---------|
| `GEMINI_MODEL` | `gemini-2.0-flash` | Model override |
| `ANALYSIS_TIMEOUT_SECONDS` | `15` | Gemini call timeout |
| `ALLOWED_ORIGINS` | `["http://localhost:3000"]` | CORS allowed origins — set to production frontend URL |
| `APP_ENV` | `development` | Environment label |
| `SKIP_EMAIL_VERIFICATION` | `True` | Set `False` in production to disable dev-only register endpoint |

### Flutter (--dart-define at build time)

| Variable | Purpose |
|----------|---------|
| `AUTH_PROVIDER` | `supabase` (default) \| `mock` \| `dev`. Must be `supabase` in production — see [Auth Overview](../auth/00_overview.md) |
| `SUPABASE_URL` | Supabase project URL for Flutter Supabase SDK. Required when `AUTH_PROVIDER=supabase`; `AppConfig.validate()` in `main.dart` throws a readable `StateError` at startup if missing instead of letting the SDK initialize with an empty URL |
| `SUPABASE_ANON_KEY` | Supabase anon key for Flutter Supabase SDK. Same fail-fast behavior as `SUPABASE_URL` |
| `API_BASE_URL` | Backend Cloud Run URL |
| `USE_MOCK_DATA` | Must be `false` in production (defaults to `true`) |
| `SKIP_EMAIL_VERIFICATION` | Must be `false` in production (defaults to `true`) |

`scripts/deploy_web.sh` sets all of these correctly for `production`; do not pass them by hand.
