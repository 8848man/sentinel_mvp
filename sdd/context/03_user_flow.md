# 03 — User Flow

**Refs:** → [Screen Spec](./04_screen_spec.md) · [Product Spec](./02_product_spec.md)

---

## Primary Flow

```
[App Launch]
     │
     ├─ Has valid session? ──Yes──> [Dashboard]
     │
     No
     ↓
[Login Screen]
     │
     ├─ Enter email + password → Continue
     │       │
     │       ├─ Success ──────────────────────────> [Dashboard]
     │       └─ Error   → show inline error message
     │
     └─ "sign up" link
             ↓
     [Sign Up Screen]
             │
             ├─ Enter password + validation code + email → Continue
             │       │
             │       ├─ Success ──────────────────> [Dashboard]
             │       └─ Error   → show inline error message
```

---

## Dashboard Flow

```
[Dashboard]
     │
     ├─ Toggle "Status View" / "Severity View"
     │       └─ Re-renders columns in-place (no navigation)
     │
     ├─ Click "+ Register Incident"
     │       └──> [Incident Registration]
     │
     ├─ Click "Archive"
     │       └──> [Closed Incidents Archive]
     │
     └─ Click incident card
             └──> [Incident Detail / Workspace]
```

---

## Incident Registration Flow

```
[Incident Registration]
     │
     ├─ User pastes log text in left panel input (or description)
     ├─ AI metadata auto-fills right panel fields (streaming or on-demand)
     ├─ User edits: Title, Severity, Architecture components
     │
     └─ Click "Analyze Incident"
             │
             ├─ POST /api/v1/incidents  (creates incident, triggers AI analysis)
             └──> [AI Analysis & Resolution]
```

**OCR-assisted Raw Log extraction (optional sub-flow — spec only, not yet implemented):**
```
[Incident Registration]
     │
     └─ Click "Scan / Upload Image" beside the Raw Log field
             ↓
     [Review Screen] (modal overlay, not a route)
             │
             ├─ "Use Cleaned Log" / "Use OCR Original" → inserts text into Raw Log field, closes overlay
             └─ "Cancel" → closes overlay, Raw Log unchanged
```
See [`04_1_ocr_log_extraction.md`](./04_1_ocr_log_extraction.md) for the full image → OCR → cleanup pipeline.

---

## AI Analysis & Resolution Flow

```
[AI Analysis & Resolution]
     │
     ├─ Left panel loads: Root Cause, Confidence, Similar Incidents
     ├─ Right panel loads: Recommended Fix Flows (ranked by confidence)
     │
     ├─ Click "View Details" on Similar Incident
     │       └──> [Incident Detail Dialog] (modal overlay, no navigation)
     │               └─ Close dialog → back to [AI Analysis & Resolution]
     │
     └─ Click a Fix Flow row (select it)
             │
             ├─ PATCH /api/v1/incidents/{id}  (attach fix_flow_id, set status: in_progress)
             └──> [Incident Detail / Workspace]
```

---

## Incident Detail / Workspace Flow

```
[Incident Detail / Workspace]
     │
     ├─ Check/uncheck checklist items
     │       └─ PATCH /api/v1/checklist/{item_id}  (auto-save on toggle)
     │
     ├─ Type in Notes textarea
     │       └─ PUT /api/v1/incidents/{id}/note  (debounced auto-save, 1s)
     │
     ├─ Click "Back to Analysis"
     │       ├─ State already persisted (checklist + notes written on each change)
     │       └──> [AI Analysis & Resolution]  (incident_id passed via route)
     │
     └─ Click "Mark as Resolved"
             ├─ PATCH /api/v1/incidents/{id}/resolve
             └──> [Dashboard]  (incident now shows in Resolved column)
```

---

## Archive Flow

```
[Closed Incidents Archive]
     │
     └─ Click any archive row
             └──> [Incident Detail Dialog] (modal)
                     └─ Close → back to [Closed Incidents Archive]
```

---

## Navigation State Rules

| From | To | State Preserved |
|------|----|-----------------|
| Workspace → AI Analysis (Back) | AI Analysis | checklist states, note content |
| AI Analysis → Workspace (Fix Flow select) | Workspace | previously attempted flags |
| Dashboard → Workspace (card click) | Workspace | full incident state from DB |
| Any screen → Dashboard (resolve) | Dashboard | updated status columns |

---

## Route Map

| Route | Screen |
|-------|--------|
| `/login` | Login |
| `/signup` | Sign Up |
| `/dashboard` | Dashboard |
| `/incidents/new` | Incident Registration |
| `/incidents/:id/analysis` | AI Analysis & Resolution |
| `/incidents/:id/workspace` | Incident Detail / Workspace |
| `/archive` | Closed Incidents Archive |
| (modal overlay) | Incident Detail Dialog |

---

## Sign-Up Flow Note (Design Deviation)

The `sign_up.png` shows fields in order: **Password → Validation Code → Email**.  
**Assumption:** Sign-up is a two-step flow. Step 1 (not shown): user enters email on Login and clicks "sign up" link. Supabase sends OTP to that email. Step 2 (shown): user sets password, enters the OTP received, and confirms email. The email field in the design is for user confirmation/display. Backend uses Supabase `signUp` with email+password, then `verifyOtp` for the code.
