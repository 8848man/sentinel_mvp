# Sentinel — AI 장애 해결 코파일럿

Sentinel은 원시 에러 로그와 스택 트레이스를 구조화된 AI 기반 해결 워크플로우로 전환하는 웹 기반 인시던트 관리 플랫폼입니다.

> **영어 버전:** [README.md](./README.md)

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [비전](#2-비전)
3. [대상 사용자](#3-대상-사용자)
4. [핵심 사용자 흐름](#4-핵심-사용자-흐름)
5. [시스템 개요](#5-시스템-개요)
6. [저장소 구조](#6-저장소-구조)
7. [문서 맵](#7-문서-맵)
8. [시작하기](#8-시작하기)

---

## 1. 프로젝트 개요

### 무엇인가

Sentinel은 엔지니어링 운영자를 위한 AI 보조 인시던트 관리 도구입니다. 프로덕션 환경에서 문제가 발생했을 때, 엔지니어는 에러 로그를 Sentinel에 붙여넣기만 하면 됩니다. 시스템은 자동으로 구조화된 메타데이터를 추출하고, 근본 원인을 파악하며, 유사한 과거 인시던트를 찾아내고, 우선순위가 매겨진 단계별 수정 방법을 하나의 집중된 워크스페이스에서 제공합니다.

### 어떤 문제를 해결하는가

프로덕션 인시던트는 높은 압박감과 시간 제약이 있는 상황입니다. 엔지니어는 보통 다음과 같은 문제에 직면합니다:

- 즉각적인 컨텍스트 없이 비구조화된 원시 로그
- 시도한 내용과 해결된 내용을 추적할 중앙화된 공간의 부재
- 시스템이 아닌 특정 개인에게만 축적되는 조직 내 지식
- 동일한 유형의 장애를 반복적으로 진단하는 낭비

Sentinel은 "무언가 고장났다"는 상황에서 "이렇게 해결하라"는 단계까지의 간극을 좁힙니다. AI 기반 해결 파이프라인 속에 조직의 노하우를 녹여내는 방식으로요.

### 왜 중요한가

다운타임의 모든 순간은 사용자, 매출, 그리고 팀의 신뢰에 비용을 발생시킵니다. Sentinel은 구조화된 인시던트 이력을 축적하고, 이를 미래의 AI 분석에 활용함으로써 해결 프로세스를 더 빠르고, 일관성 있게 만들며, 시간이 지날수록 학습 가능한 시스템으로 발전시킵니다.

---

## 2. 비전

Sentinel의 장기적인 방향은 엔지니어링 운영의 **조직 기억 레이어**가 되는 것입니다. 더 많은 인시던트가 해결될수록 더 스마트해지는 시스템 — 평균 해결 시간(MTTR)을 줄이고, 팀 전반에 걸친 반복적인 진단 작업을 제거합니다.

**전략적 목표:**

- 올바른 수정 방법을, 올바른 사람에게, 올바른 시점에 제공
- 구조화되고 조회 가능한 인시던트 지식 베이스를 시간이 지남에 따라 구축
- 팀 전체 협업, 실시간 알림, Datadog · PagerDuty · Slack 등 옵저버빌리티 도구 연동 지원
- MVP 이후 웹에서 모바일 네이티브 앱으로 확장

---

## 3. 대상 사용자

**주요 대상: 엔지니어링 운영자 / 온콜 엔지니어**

프로덕션 인시던트에 대응하는 엔지니어. 핵심 요구사항은 속도와 명확성입니다. 여러 도구를 번갈아 가며 사용하지 않고도 무엇이 문제인지, 왜 발생했는지, 무엇부터 시도해야 하는지를 즉시 파악해야 합니다.

**보조 대상: 엔지니어링 매니저 / 팀 리드**

인시던트 이력을 검토하여 시스템 안정성 트렌드를 파악하고, 반복적인 장애를 식별하며, 해결 효과를 평가하는 이해관계자.

---

## 4. 핵심 사용자 흐름

```
[로그인 / 회원가입]
       │
       ▼
[대시보드]  ──────────────────────────────────────────┐
  모든 활성 인시던트 확인                               │
  전환: 상태 뷰 | 심각도 뷰                             │
       │                                               │
       ├─ "+ 인시던트 등록"                             │
       │         │                                     │
       │         ▼                                     │
       │  [인시던트 등록]                               │
       │    로그 / 에러 텍스트 붙여넣기                  │
       │    AI 추출: 제목, 심각도,                       │
       │    영향받은 컴포넌트                             │
       │    사용자 검토 및 확인                           │
       │         │                                     │
       │         ▼                                     │
       │  [AI 분석 및 해결]                              │
       │    근본 원인 및 신뢰도 점수                      │
       │    유사한 과거 인시던트                          │
       │    우선순위별 수정 방법                          │
       │    수정 방법 선택 →                              │
       │         │                                     │
       │         ▼                                     │
       │  [인시던트 워크스페이스]                         │
       │    단계별 해결 체크리스트                        │
       │    노트 (자동 저장)                              │
       │    이벤트 타임라인                               │
       │    "해결됨으로 표시" ──────────────────────────┘
       │
       └─ "아카이브"
                 │
                 ▼
         [완료 인시던트 아카이브]
           해결된 인시던트 조회
           상세 다이얼로그를 통해 인시던트 열람
```

**주요 동작:**

- 체크리스트 상태와 노트는 변경마다 즉시 데이터베이스에 저장됩니다. AI 분석 화면으로 돌아갔다가 다시 워크스페이스로 와도 항상 마지막 상태가 복원됩니다.
- 인시던트 ID 형식: `INC-YYYY-NNN` (예: `INC-2026-041`), 전역적으로 고유합니다.
- 심각도 수준: `Critical` · `Major` · `Minor`
- 인시던트 생명주기: `open` → `in_progress` → `resolved` → `closed`

---

## 5. 시스템 개요

```
┌─────────────────────────────────────────────────────┐
│                  브라우저 / 클라이언트               │
│            Flutter 웹 애플리케이션                   │
│   Riverpod 상태관리 · go_router · Supabase Auth SDK  │
└──────────────────────────┬──────────────────────────┘
                           │ HTTPS + JWT
┌──────────────────────────▼──────────────────────────┐
│                  백엔드 API                          │
│          FastAPI (Python 3.12) on Cloud Run          │
│   인증 검증 · 비즈니스 로직 · AI 오케스트레이션       │
└────────┬──────────────────────────┬─────────────────┘
         │                          │
┌────────▼────────┐      ┌──────────▼──────────┐
│  PostgreSQL DB  │      │  Google Gemini API   │
│  (Cloud SQL)    │      │  AI 분석 엔진         │
│  인시던트 데이터  │      │  (서버 사이드 전용)    │
└─────────────────┘      └──────────────────────┘
         │
┌────────▼────────┐
│  Supabase Auth  │
│  JWT 발급       │
│  및 관리         │
└─────────────────┘
```

### 레이어별 역할

| 레이어 | 기술 | 역할 |
|--------|------|------|
| **프론트엔드** | Flutter (Web) | UI 렌더링, 라우팅, 로컬 상태 관리, 인증 세션 처리 |
| **백엔드 API** | FastAPI + Python 3.12 | 요청 처리, JWT 검증, 비즈니스 로직, DB 접근, AI 오케스트레이션 |
| **데이터베이스** | PostgreSQL 16 (Cloud SQL) | 인시던트, 수정 방법, 체크리스트, 노트, 타임라인 영구 저장 |
| **AI 엔진** | Google Gemini 2.0 Flash | 원시 로그 메타데이터 추출, 근본 원인 분석, 수정 방법 생성 |
| **인증** | Supabase Auth | 이메일/패스워드 인증, JWT 발급, 토큰 갱신 |
| **호스팅** | Firebase Hosting (프론트) · Cloud Run (백엔드) | 프로덕션 서빙, 자동 확장 |

**주요 설계 결정:**

- Gemini API는 **서버 사이드에서만** 호출됩니다. API 키는 브라우저에 노출되지 않습니다.
- 모든 API 경로는 `/api/v1` 접두사를 사용하며 유효한 Supabase JWT가 필요합니다.
- Flutter 앱은 MVP에서 **웹(데스크톱 우선 레이아웃)**을 대상으로 합니다. 모바일(iOS/Android)은 향후 계획입니다.
- 로컬 개발 시 백엔드는 **SQLite**를 사용하므로 별도의 PostgreSQL 설치가 필요 없습니다.

---

## 6. 저장소 구조

```
sentinel_mvp/
├── backend/                  # FastAPI 백엔드 서비스
│   ├── app/
│   │   ├── core/             # 설정, 데이터베이스 엔진, JWT 인증
│   │   ├── routers/          # 라우트 핸들러 (얇은 레이어)
│   │   ├── services/         # 비즈니스 로직 및 AI 오케스트레이션
│   │   ├── models/           # SQLAlchemy ORM 모델
│   │   └── schemas/          # Pydantic 요청/응답 스키마
│   ├── tests/                # 단위 및 통합 테스트
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
│
├── database/
│   ├── migrations/           # SQL 마이그레이션 스크립트
│   └── seed.sql              # 개발용 시드 데이터
│
├── deployment/
│   ├── cloudbuild.yaml       # GCP Cloud Build CI/CD 파이프라인
│   └── k8s/                  # Kubernetes 매니페스트 (참고용)
│
├── frontend/
│   └── sentinel/             # 주요 Flutter 웹 애플리케이션
│       ├── lib/
│       │   ├── core/         # API 클라이언트, 라우터, 인증
│       │   ├── design_system/# 공유 토큰, 컴포넌트
│       │   └── features/     # 화면 단위 기능 모듈
│       └── pubspec.yaml
│
├── sdd/                      # 소프트웨어 설계 문서
│   ├── context/              # 요구사항, 제품 명세, 사용자 흐름
│   ├── backend/              # API 명세, DB 스키마, 인증, AI 연동
│   ├── frontend/             # 프론트엔드 아키텍처, 폴더 구조
│   └── infra/                # 배포 및 테스트 명세
│
└── sentinel_screen_ref/      # UI 디자인 참고 스크린샷 (PNG)
```

---

## 7. 문서 맵

| 문서 | 목적 |
|------|------|
| [SDD 인덱스](./sdd/00_index.md) | 마스터 인덱스 및 문서 간 의존성 맵 |
| [요구사항](./sdd/context/01_requirements.md) | 기능 및 비기능 요구사항 |
| [제품 명세](./sdd/context/02_product_spec.md) | MVP 범위, 기능 우선순위, 데이터 모델 |
| [사용자 흐름](./sdd/context/03_user_flow.md) | 내비게이션 경로 및 상태 전환 |
| [화면 명세](./sdd/context/04_screen_spec.md) | 9개 화면과 디자인 참고 이미지 매핑 |
| [API 명세](./sdd/backend/05_api_spec.md) | 요청/응답 계약을 포함한 REST 엔드포인트 |
| [데이터베이스 스키마](./sdd/backend/06_database_schema.md) | PostgreSQL 테이블, 제약조건, 인덱스 |
| [인증 명세](./sdd/backend/07_auth_spec.md) | Supabase Auth 흐름 및 JWT 검증 |
| [AI 연동 명세](./sdd/backend/08_ai_integration_spec.md) | Gemini 프롬프트, 파싱, AI 흐름 |
| [백엔드 아키텍처](./sdd/backend/09_backend_arch.md) | FastAPI 구조, 서비스, 미들웨어 |
| [프론트엔드 아키텍처](./sdd/frontend/10_frontend_arch.md) | Flutter 구조, 디자인 시스템, 라우팅 |
| [배포 명세](./sdd/infra/11_deployment_spec.md) | GCP 서비스, CI/CD, 환경 설정 |
| [테스트 명세](./sdd/infra/12_testing_spec.md) | 단위, 위젯, 통합, API 테스트 |

---

## 8. 시작하기

### 사전 요구사항

| 도구 | 버전 | 대상 |
|------|------|------|
| Python | 3.12 이상 | 백엔드 |
| Flutter SDK | 3.x (stable) | 프론트엔드 |
| Git | 무관 | 공통 |
| Gemini API 키 | — | 백엔드 AI 기능 |

---

### 백엔드 설정

**1. 백엔드 디렉토리로 이동**

```bash
cd backend
```

**2. 가상환경 생성 및 활성화**

```bash
python -m venv .venv

# macOS / Linux
source .venv/bin/activate

# Windows (PowerShell)
.\.venv\Scripts\Activate.ps1
```

**3. 의존성 설치**

```bash
pip install -r requirements.txt
```

**4. 환경 변수 설정**

```bash
cp .env.example .env
```

`.env` 파일을 열고 값을 설정합니다:

```env
APP_ENV=development

# SQLite (로컬 개발 시 외부 DB 불필요)
DATABASE_URL=sqlite+aiosqlite:///./sentinel_dev.db

# 인증 — 로컬 개발 시 임의 문자열 사용 가능
SUPABASE_JWT_SECRET=dev-insecure-secret-change-in-production

# AI — 인시던트 분석 기능에 필수
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-2.0-flash
GEMINI_TIMEOUT_SECONDS=15

# CORS — Flutter 개발 서버 허용
ALLOWED_ORIGINS=["http://localhost:3000","http://localhost:5173"]
```

> 기본적으로 **SQLite**를 사용하므로 로컬 개발 시 PostgreSQL 설치가 필요 없습니다.

**5. 백엔드 서버 실행**

```bash
uvicorn app.main:app --reload --port 8000
```

API는 `http://localhost:8000`에서 사용할 수 있습니다.  
인터랙티브 API 문서: `http://localhost:8000/docs`

---

### 프론트엔드 설정

**1. Flutter 앱 디렉토리로 이동**

```bash
cd frontend/sentinel
```

**2. Flutter 의존성 설치**

```bash
flutter pub get
```

**3. 환경 변수 설정**

Flutter 앱은 빌드/실행 시 `--dart-define` 플래그를 통해 설정을 읽습니다. 로컬 개발 시 아래와 같이 실행합니다:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=API_BASE_URL=http://localhost:8000
```

> `SUPABASE_URL`과 `SUPABASE_ANON_KEY`는 [supabase.com](https://supabase.com)에서 무료 프로젝트를 생성한 후 **프로젝트 설정 → API**에서 확인할 수 있습니다.

**4. 프론트엔드 실행**

```bash
flutter run -d chrome
```

앱이 Chrome에서 자동으로 열립니다. Flutter 개발 서버는 보통 포트 `3000` 또는 `5173`에서 실행됩니다.

---

### 개발 워크플로우

**권장 실행 순서:**

1. 먼저 백엔드를 시작합니다 (`uvicorn app.main:app --reload --port 8000`)
2. 그 다음 프론트엔드를 시작합니다 (`flutter run -d chrome ...`)

**두 서비스가 정상 실행 중인지 확인:**

| 확인 항목 | URL |
|-----------|-----|
| 백엔드 상태 | `http://localhost:8000/docs` — Swagger UI가 표시되어야 합니다 |
| 프론트엔드 | 브라우저가 자동으로 열리며 로그인 화면이 나타나야 합니다 |
| API 연결 | 인시던트를 등록했을 때 AI 분석 결과가 반환되면 전체 스택이 정상 연결된 것입니다 |

**백엔드 테스트 실행:**

```bash
cd backend
pytest
```
