# 11 — Deployment Specification

**Cloud:** Google Cloud Platform (GCP)  
**Refs:** → [Backend Architecture](../backend/09_backend_arch.md) · [Database Schema](../backend/06_database_schema.md)

---

## Services

| Service | GCP Product | Purpose |
|---------|-------------|---------|
| Backend API | Cloud Run | Containerized FastAPI, auto-scales to zero |
| Frontend | Firebase Hosting | Flutter web build, CDN-served |
| Database | Cloud SQL (PostgreSQL 16) | Managed PostgreSQL, private IP |
| Secrets | Secret Manager | API keys, DB credentials, JWT secret |
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
            - name: SUPABASE_JWT_SECRET
              valueFrom:
                secretKeyRef: { name: sentinel-supabase-jwt, version: latest }
            - name: GEMINI_API_KEY
              valueFrom:
                secretKeyRef: { name: sentinel-gemini-key, version: latest }
          resources:
            limits: { memory: 512Mi, cpu: "1" }
```

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

**Initial setup:**
```bash
gcloud sql connect sentinel-db --user=postgres
# Run: /database/migrations/001_initial_schema.sql
```

---

## Frontend: Firebase Hosting

```bash
# Build Flutter web
flutter build web --release

# Deploy
firebase deploy --only hosting
```

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

## Environment Variables Summary

| Variable | Source | Used By |
|----------|--------|---------|
| `DATABASE_URL` | Secret Manager | Backend |
| `SUPABASE_JWT_SECRET` | Secret Manager | Backend |
| `GEMINI_API_KEY` | Secret Manager | Backend |
| `SUPABASE_URL` | Flutter dart-defines | Frontend |
| `SUPABASE_ANON_KEY` | Flutter dart-defines | Frontend |
| `API_BASE_URL` | Flutter dart-defines | Frontend |

Flutter env vars are injected at build time via `--dart-define`:
```bash
flutter build web --dart-define=SUPABASE_URL=xxx --dart-define=API_BASE_URL=yyy
```
