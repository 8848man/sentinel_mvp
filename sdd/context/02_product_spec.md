# 02 — Product Specification

**Refs:** → [Requirements](./01_requirements.md) · [User Flow](./03_user_flow.md)

---

## Vision

Sentinel is an AI Error Resolution Copilot for engineering operators.  
It transforms raw error logs and stack traces into structured incidents,  
AI-powered root cause analysis, and guided fix flows with progress tracking.

---

## MVP Scope

### In Scope

| Feature | Priority | Notes |
|---------|----------|-------|
| Email/password authentication | P0 | Via Supabase Auth |
| Incident Dashboard (Status View) | P0 | 3-column kanban |
| Incident Dashboard (Severity View) | P0 | 3-column by severity |
| Incident Registration with AI metadata extraction | P0 | Log paste → AI fill |
| AI Root Cause Analysis | P0 | Gemini API |
| Recommended Fix Flows | P0 | Ranked by confidence |
| Incident Detail / Workspace | P0 | Checklist + Notes |
| Mark as Resolved | P0 | Status transition |
| Back to Analysis (with state save) | P0 | Checklist preserved |
| Closed Incidents Archive | P1 | Read-only table |
| Incident Detail Dialog | P1 | Modal from archive / similar |
| Similar Incident matching | P1 | Displayed in AI Analysis |
| OCR-assisted Raw Log extraction (image → text) | P2 | Spec only — see [`04_1_ocr_log_extraction.md`](./04_1_ocr_log_extraction.md); not yet implemented |

### Out of Scope (MVP)

- Real-time alerts / webhooks
- Team/multi-user collaboration (comments, mentions)
- Mobile (iOS / Android) build
- Custom severity levels beyond Critical / Major / Minor
- Audit log export
- Slack / PagerDuty integration
- Role-based access control (RBAC)
- OCR-assisted extraction for the Description field (Raw Log only for this pass — see OCR8 in `04_1_ocr_log_extraction.md`)

---

## Data Model Summary

```
User (Supabase)
  └─< Incident
          ├── status: open | in_progress | resolved | closed
          ├── severity: critical | major | minor
          ├─< TimelineEvent
          ├─< FixFlow
          │       └─< ChecklistItem
          ├─< Note
          └─< SimilarIncident (reference to another Incident)
```

---

## AI-Assisted Features

### Metadata Extraction (on log paste)
- Input: raw log / stack trace / description text
- Output: suggested_id, suggested_title, suggested_severity, detected_components[]

### Root Cause Analysis (on incident creation)
- Input: incident log text + detected components
- Output: root_cause_text, confidence (0.0–1.0), similar_incidents[], fix_flows[]

### Fix Flow Generation
- Each fix flow has: title, confidence, ordered checklist_items[]
- Fix flows are stored in DB after AI generation; not re-generated on each view

---

## Incident Lifecycle

```
[Registration] → status: open
     ↓ (AI Analysis completes)
[AI Analysis]  → status: open (displayed)
     ↓ (Fix Flow selected)
[Workspace]    → status: in_progress
     ↓ (Mark as Resolved)
[Resolved]     → status: resolved
     ↓ (auto-archived or manual Archive action)
[Archive]      → status: closed
```

**State save on "Back to Analysis":**  
Checklist item states and note content are persisted to DB immediately before navigation.  
Re-entering Workspace restores saved state.

---

## Incident ID Generation

- Format: `INC-{YEAR}-{SEQ}` where SEQ is zero-padded to 3 digits
- AI suggests ID based on year + next available sequence number
- Backend assigns the canonical ID on incident creation (AI suggestion is editable)
- Sequence is global (not per-user) for consistent IDs

---

## Design System Mandate

All UI must use components from `/frontend/sentinel/lib/design_system/`.  
No screen may define its own color, typography, or spacing outside of design tokens.  
See [Frontend Architecture](../frontend/10_frontend_arch.md) for the full Design System spec.
