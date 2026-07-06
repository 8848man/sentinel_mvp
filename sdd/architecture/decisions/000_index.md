# Architecture Decision Records — Index

**Purpose:** Running index of every ADR. Update this file whenever an ADR is added, superseded, or deprecated — one line per ADR, do not duplicate ADR content here.

**Lifecycle:** `Proposed` → `Accepted` → `Superseded by ADR-NNNN` | `Deprecated`. Accepted ADRs are immutable — a changed decision is a new ADR, never an edit to an existing one. Numbers are never reused.

**Template:** [`ADR-0000-template.md`](./ADR-0000-template.md)

---

| ADR | Title | Status | Summary |
|---|---|---|---|
| [ADR-0001](./ADR-0001-jwt-validator-dispatch.md) | JWT Validator Dispatch by `iss` Claim for Dev Authentication | Accepted | Dev-only HS256 tokens routed via `iss: "sentinel-dev"`, dispatched alongside Supabase ES256 verification without weakening production auth |
| [ADR-0002](./ADR-0002-sqlite-dev-postgres-prod.md) | Dual Database Mode — SQLite Dev / PostgreSQL Prod | Accepted | `init_db()` for SQLite only; PostgreSQL schema managed exclusively by Alembic |
| [ADR-0003](./ADR-0003-supabase-publishable-key.md) | Use Supabase Publishable Key Format | Accepted | `sb_publishable_...` over the legacy `anon` JWT key format, for clearer privileged-vs-public key distinction |
| [ADR-0004](./ADR-0004-ai-platform-handler-registry.md) | AI Platform Handler/Registry Plugin Architecture | Accepted | Self-describing handler classes + registry, replacing per-capability branching |

---

**When to add a new ADR:** the decision spans more than one area in `sdd/rules/ownership.md`, is expensive to reverse, was chosen among real alternatives, or wouldn't be reconstructible from the code alone. See `sdd/workflow/02_decision_flow.md` Decision 9.

**When not to:** routine CRUD endpoints, a new AI Platform handler following the existing pattern, bug fixes, most refactors.
