# Sentinel — AI Error Resolution Copilot

Sentinel is a web-based incident management platform that transforms raw error logs and stack traces into structured, actionable resolution workflows — powered by AI.

> **Korean version:** [README_KO.md](./README_KO.md)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Vision](#2-vision)
3. [Target Users](#3-target-users)
4. [Core User Flow](#4-core-user-flow)
5. [System Overview](#5-system-overview)
6. [Repository Structure](#6-repository-structure)
7. [Documentation Map](#7-documentation-map)
8. [Getting Started](#8-getting-started)

---

## 1. Project Overview

### What It Is

Sentinel is an AI-assisted incident management tool for engineering operators. When something breaks in production, engineers paste their error logs into Sentinel. The system automatically extracts structured metadata, identifies the likely root cause, surfaces similar past incidents, and presents ranked, step-by-step fix flows — all in one focused workspace.

### What Problem It Solves

Production incidents are high-pressure, time-sensitive events. Engineers typically face:

- Unstructured raw logs with no immediate context
- No centralized place to track what was tried and what worked
- Institutional knowledge locked inside individuals, not the system
- Repeated effort diagnosing the same class of failure

Sentinel collapses the gap between "something is broken" and "here is what to do about it" by encoding that institutional knowledge into an AI-driven resolution pipeline.

### Why It Matters

Every minute of downtime has a cost — to users, to revenue, and to team confidence. Sentinel makes the resolution process faster, more consistent, and more learnable over time by accumulating structured incident history that feeds future AI analysis.

---

## 2. Vision

Sentinel's long-term direction is to become the **institutional memory layer** for engineering operations: a system that grows smarter as more incidents are resolved through it, reducing mean time to resolution (MTTR) and eliminating redundant diagnostic work across teams.

**Strategic goals:**

- Surface the right fix, to the right person, at the right time
- Build a structured, queryable incident knowledge base over time
- Eventually support team-wide collaboration, real-time alerting, and integration with observability tools (Datadog, PagerDuty, Slack)
- Extend from web to native mobile as the user base grows

---

## 3. Target Users

**Primary: Engineering Operators / On-call Engineers**

Engineers who respond to production incidents. Their core needs are speed and clarity — they need to know what broke, why, and what to try first, without context-switching across multiple tools.

**Secondary: Engineering Managers / Team Leads**

Stakeholders who review incident history to understand system reliability trends, identify recurring failures, and evaluate resolution effectiveness.

---

## 4. Core User Flow

```
[Login / Sign Up]
       │
       ▼
[Dashboard]  ──────────────────────────────────────┐
  View all active incidents                         │
  Toggle: Status View | Severity View               │
       │                                            │
       ├─ "+ Register Incident"                     │
       │         │                                  │
       │         ▼                                  │
       │  [Incident Registration]                   │
       │    Paste logs / error text                 │
       │    AI extracts: title, severity,           │
       │    affected components                     │
       │    User reviews & confirms                 │
       │         │                                  │
       │         ▼                                  │
       │  [AI Analysis & Resolution]                │
       │    Root cause & confidence score           │
       │    Similar past incidents                  │
       │    Ranked fix flows                        │
       │    Select a fix flow →                     │
       │         │                                  │
       │         ▼                                  │
       │  [Incident Workspace]                      │
       │    Step-by-step resolution checklist       │
       │    Notes (auto-saved)                      │
       │    Timeline of events                      │
       │    "Mark as Resolved" ──────────────────────┘
       │
       └─ "Archive"
                 │
                 ▼
         [Closed Incidents Archive]
           View resolved incidents
           Inspect any incident via detail dialog
```

**Key behaviors:**

- Checklist state and notes are persisted to the database on every change — navigating back to AI Analysis and returning to the Workspace always restores exactly where you left off.
- Incident IDs follow the format `INC-YYYY-NNN` (e.g., `INC-2026-041`) and are globally unique.
- Severity levels: `Critical` · `Major` · `Minor`
- Incident lifecycle: `open` → `in_progress` → `resolved` → `closed`

---

## 5. System Overview

```
┌─────────────────────────────────────────────────────┐
│                   Browser / Client                  │
│            Flutter Web Application                  │
│   Riverpod state · go_router · Supabase Auth SDK    │
└──────────────────────────┬──────────────────────────┘
                           │ HTTPS + JWT
┌──────────────────────────▼──────────────────────────┐
│                  Backend API                        │
│          FastAPI (Python 3.12) on Cloud Run         │
│   Auth validation · Business logic · AI orchestration│
└────────┬──────────────────────────┬─────────────────┘
         │                          │
┌────────▼────────┐      ┌──────────▼──────────┐
│  PostgreSQL DB  │      │   Google Gemini API  │
│  (Cloud SQL)    │      │  AI analysis engine  │
│  Incident data  │      │  (server-side only)  │
└─────────────────┘      └─────────────────────-┘
         │
┌────────▼────────┐
│  Supabase Auth  │
│  JWT issuance   │
│  & management   │
└─────────────────┘
```

### Layer Responsibilities

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| **Frontend** | Flutter (Web) | UI rendering, routing, local state management, auth session handling |
| **Backend API** | FastAPI + Python 3.12 | Request handling, JWT validation, business logic, database access, AI orchestration |
| **Database** | PostgreSQL 16 (Cloud SQL) | Persistent storage for incidents, fix flows, checklists, notes, and timelines |
| **AI Engine** | Google Gemini 2.0 Flash | Metadata extraction from raw logs, root cause analysis, fix flow generation |
| **Auth** | Supabase Auth | Email/password authentication, JWT issuance, token refresh |
| **Hosting** | Firebase Hosting (frontend) · Cloud Run (backend) | Production serving, auto-scaling |

**Key design decisions:**

- The Gemini API is called **server-side only**. The API key is never exposed to the browser.
- All API routes are prefixed `/api/v1` and require a valid Supabase JWT.
- The Flutter app targets **web with a desktop-first layout** for the MVP. Mobile (iOS/Android) is future scope.
- For local development, the backend uses **SQLite** so no external database is required.

---

## 6. Repository Structure

```
sentinel_mvp/
├── backend/                  # FastAPI backend service
│   ├── app/
│   │   ├── core/             # Config, database engine, JWT auth
│   │   ├── routers/          # Route handlers (thin layer)
│   │   ├── services/         # Business logic and AI orchestration
│   │   ├── models/           # SQLAlchemy ORM models
│   │   └── schemas/          # Pydantic request/response schemas
│   ├── tests/                # Unit and integration tests
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
│
├── database/
│   ├── migrations/           # SQL migration scripts
│   └── seed.sql              # Development seed data
│
├── deployment/
│   ├── cloudbuild.yaml       # GCP Cloud Build CI/CD pipeline
│   └── k8s/                  # Kubernetes manifests (reference)
│
├── frontend/
│   └── sentinel/             # Primary Flutter web application
│       ├── lib/
│       │   ├── core/         # API client, router, auth
│       │   ├── design_system/# Shared tokens, components
│       │   └── features/     # Screen-level feature modules
│       └── pubspec.yaml
│
├── sdd/                      # Software Design Documents
│   ├── context/              # Requirements, product spec, user flow
│   ├── backend/              # API spec, DB schema, auth, AI integration
│   ├── frontend/             # Frontend architecture, folder structure
│   └── infra/                # Deployment and testing specs
│
└── sentinel_screen_ref/      # UI design reference screenshots (PNG)
```

---

## 7. Documentation Map

| Document | Purpose |
|----------|---------|
| [SDD Index](./sdd/00_index.md) | Master index and cross-document dependency map |
| [Requirements](./sdd/context/01_requirements.md) | Functional and non-functional requirements |
| [Product Spec](./sdd/context/02_product_spec.md) | MVP scope, feature priorities, data model |
| [User Flow](./sdd/context/03_user_flow.md) | Navigation paths and state transitions |
| [Screen Spec](./sdd/context/04_screen_spec.md) | All 9 screens mapped to design references |
| [API Spec](./sdd/backend/05_api_spec.md) | REST endpoints with request/response contracts |
| [Database Schema](./sdd/backend/06_database_schema.md) | PostgreSQL tables, constraints, indexes |
| [Auth Spec](./sdd/backend/07_auth_spec.md) | Supabase Auth flow and JWT validation |
| [AI Integration Spec](./sdd/backend/08_ai_integration_spec.md) | Gemini prompts, parsing, and AI flows |
| [Backend Architecture](./sdd/backend/09_backend_arch.md) | FastAPI structure, services, middleware |
| [Frontend Architecture](./sdd/frontend/10_frontend_arch.md) | Flutter structure, design system, routing |
| [Deployment Spec](./sdd/infra/11_deployment_spec.md) | GCP services, CI/CD, environment config |
| [Testing Spec](./sdd/infra/12_testing_spec.md) | Unit, widget, integration, and API tests |

---

## 8. Getting Started

### Prerequisites

| Tool | Version | Required For |
|------|---------|-------------|
| Python | 3.12+ | Backend |
| Flutter SDK | 3.x (stable) | Frontend |
| Git | any | Both |
| Gemini API Key | — | Backend AI features |

---

### Backend Setup

**1. Navigate to the backend directory**

```bash
cd backend
```

**2. Create and activate a virtual environment**

```bash
python -m venv .venv

# macOS / Linux
source .venv/bin/activate

# Windows (PowerShell)
.\.venv\Scripts\Activate.ps1
```

**3. Install dependencies**

```bash
pip install -r requirements.txt
```

**4. Configure environment variables**

```bash
cp .env.example .env
```

Open `.env` and set your values:

```env
APP_ENV=development

# SQLite (no external DB needed for local dev)
DATABASE_URL=sqlite+aiosqlite:///./sentinel_dev.db

# Auth — use any string for local dev
SUPABASE_JWT_SECRET=dev-insecure-secret-change-in-production

# AI — required for incident analysis features
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-2.0-flash
GEMINI_TIMEOUT_SECONDS=15

# CORS — allow the Flutter dev server
ALLOWED_ORIGINS=["http://localhost:3000","http://localhost:5173"]
```

> The backend uses **SQLite** by default in development — no PostgreSQL installation required.

**5. Run the backend server**

```bash
uvicorn app.main:app --reload --port 8000
```

The API will be available at `http://localhost:8000`.  
Interactive API docs: `http://localhost:8000/docs`

---

### Frontend Setup

**1. Navigate to the Flutter app**

```bash
cd frontend/sentinel
```

**2. Install Flutter dependencies**

```bash
flutter pub get
```

**3. Configure environment variables**

The Flutter app reads its configuration via `--dart-define` flags at build/run time. For local development, create a launch script or pass them directly:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=API_BASE_URL=http://localhost:8000
```

> To get `SUPABASE_URL` and `SUPABASE_ANON_KEY`, create a free project at [supabase.com](https://supabase.com) and copy the values from **Project Settings → API**.

**4. Run the frontend**

```bash
flutter run -d chrome
```

The app will open in Chrome. The Flutter dev server typically runs on port `3000` or `5173`.

---

### Development Workflow

**Recommended startup order:**

1. Start the backend first (`uvicorn app.main:app --reload --port 8000`)
2. Start the frontend second (`flutter run -d chrome ...`)

**Verify both services are running:**

| Check | URL |
|-------|-----|
| Backend health | `http://localhost:8000/docs` — should show the Swagger UI |
| Frontend | Browser opens automatically; login screen should appear |
| API connectivity | Register an incident — if AI analysis returns results, the full stack is connected |

**Running backend tests:**

```bash
cd backend
pytest
```
