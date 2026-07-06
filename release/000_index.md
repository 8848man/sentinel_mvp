# Release Index

**Purpose:** Current released versions and where to find release history. `release/` sits outside `sdd/` deliberately — it records what was actually deployed to this repository's real infrastructure at a point in time, not what the system is designed to be. Specifications must remain unaware of this directory (see `sdd/rules/spec_authoring_rules.md`); this directory may freely reference specs, ADRs, and git tags.

**Structure:**
- `project/` — dated rollup entries (`REL-YYYY-MM-DD`), reference component versions, never duplicate their technical detail
- `frontend/` — Flutter web app, independent semantic version, tagged `frontend-vX.Y.Z`
- `backend/` — FastAPI backend, independent semantic version, tagged `backend-vX.Y.Z`

Each periodized by year (`2026.md`, ...) to bound file growth, mirroring the size discipline `sdd/rules/spec_authoring_rules.md` already applies to specs.

**Rules:**
- Frontend and backend version independently — a frontend patch does not require a backend bump or vice versa.
- Every release entry references a **git tag**, never a raw commit hash (tag the commit, then write the entry).
- Project Release is a rollup only — it names which frontend/backend versions it bundles; frontend/backend release logs never reference Project Release back (see `sdd/architecture/decisions/000_index.md` philosophy — same one-directional-reference principle as ADR→Spec).
- A release entry is written only when something is **actually deployed** — never at commit time, never speculatively.

---

## Currently Released

| Component | Version | Tag | Deployed to |
|---|---|---|---|
| Frontend | 1.0.0 | `frontend-v1.0.0` | `https://sentinel-mvp-eeeee.web.app` (Firebase Hosting) |
| Backend | 1.0.0 | `backend-v1.0.0` | `https://sentinel-backend-twyh3esabq-du.a.run.app` (Cloud Run) |

Latest project rollup: [`REL-2026-07-06`](./project/2026.md#rel-2026-07-06)

---

## History

- [Project releases — 2026](./project/2026.md)
- [Frontend releases — 2026](./frontend/2026.md)
- [Backend releases — 2026](./backend/2026.md)
- Pre-2026-07-06 history (before this structure existed): [`sdd/archive/work_history.md`](../sdd/archive/work_history.md)
