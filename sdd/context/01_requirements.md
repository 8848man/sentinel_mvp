# 01 — Requirements

**Refs:** → [Product Spec](./02_product_spec.md) · [API Spec](../backend/05_api_spec.md)

---

## Functional Requirements

### Authentication
| ID | Requirement |
|----|-------------|
| FR-AUTH-01 | User can sign in with email and password via Supabase Auth |
| FR-AUTH-02 | User can sign up; sign-up requires email, password, and a validation code |
| FR-AUTH-03 | Unauthenticated users are redirected to Login screen |
| FR-AUTH-04 | Session persists via Supabase refresh token stored securely on device |
| FR-AUTH-05 | Backend validates Supabase JWT on every protected request |

### Dashboard
| ID | Requirement |
|----|-------------|
| FR-DASH-01 | Dashboard displays incidents grouped by status: Open / In Progress / Resolved |
| FR-DASH-02 | Dashboard can be toggled to Severity View: Critical / Major / Minor |
| FR-DASH-03 | Each incident card displays: Incident ID, Title, Description, Severity badge |
| FR-DASH-04 | Status View severity badges; Severity View shows status badges |
| FR-DASH-05 | Clicking a card navigates to Incident Detail / Workspace |
| FR-DASH-06 | "Archive" button navigates to Closed Incidents Archive |
| FR-DASH-07 | "+ Register Incident" button navigates to Incident Registration |
| FR-DASH-08 | Current UTC time is displayed and updates every minute |

### Incident Registration
| ID | Requirement |
|----|-------------|
| FR-REG-01 | User pastes logs, stack traces, or plain description |
| FR-REG-02 | "Analyze Incident" triggers AI metadata extraction |
| FR-REG-03 | AI returns: Suggested ID, Title, Severity, Detected Architecture components |
| FR-REG-04 | User can edit Suggested Title and Severity before creation |
| FR-REG-05 | User can remove incorrect architecture components |
| FR-REG-06 | User can manually add architecture components |
| FR-REG-07 | Clicking "Analyze Incident" creates the incident and transitions to AI Analysis screen |

### AI Analysis & Resolution
| ID | Requirement |
|----|-------------|
| FR-AI-01 | Screen displays Likely Root Cause text from Gemini analysis |
| FR-AI-02 | Screen displays Confidence percentage (0–100) |
| FR-AI-03 | Screen displays up to 5 Similar Incidents with match % |
| FR-AI-04 | Screen lists Recommended Fix Flows with confidence %, progress, and Attempted flag |
| FR-AI-05 | Clicking "View Details" on a Similar Incident opens Incident Detail Dialog |
| FR-AI-06 | Selecting a Fix Flow attaches it to the incident and navigates to Workspace |

### Incident Detail / Workspace
| ID | Requirement |
|----|-------------|
| FR-WS-01 | Left panel shows: Incident ID, Title, Severity badge, Timeline |
| FR-WS-02 | Right panel shows: Resolution Checklist, Selected Fix Flow, Notes textarea |
| FR-WS-03 | Checklist items can be toggled (checked/unchecked) |
| FR-WS-04 | Notes can be written and auto-saved (debounced 1s) |
| FR-WS-05 | "Back to Analysis" saves current checklist + note state and navigates to AI Analysis |
| FR-WS-06 | "Mark as Resolved" sets status to `resolved`, records resolved_at timestamp |

### Archive
| ID | Requirement |
|----|-------------|
| FR-ARC-01 | Archive lists resolved incidents in a table |
| FR-ARC-02 | Columns: Incident ID, Incident Name, Severity, Resolution Time, Status |
| FR-ARC-03 | Clicking an archive row opens Incident Detail Dialog |

### Incident Detail Dialog
| ID | Requirement |
|----|-------------|
| FR-DLG-01 | Modal shows: Incident Code, Name, Status badge, Severity badge |
| FR-DLG-02 | Left panel: Timeline events list |
| FR-DLG-03 | Right panel: Incident Summary (Root Cause, Impact, Fix Flow), Memo |

---

## Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-01 | AI analysis response time | < 10 seconds p95 |
| NFR-02 | Dashboard load time | < 2 seconds |
| NFR-03 | API availability | 99.5% uptime |
| NFR-04 | Authentication token expiry | 1 hour; refresh silently |
| NFR-05 | All API communication over HTTPS | Enforced in production |
| NFR-06 | Data persistence for in-progress checklist on "Back to Analysis" | Immediate DB write |
| NFR-07 | Flutter app targets Web (primary MVP target) | Desktop-first layout |

---

## Constraints

- Auth is fully managed by Supabase Auth; no custom auth server
- Gemini API called server-side only; API key never exposed to client
- PostgreSQL hosted on GCP Cloud SQL
- Backend deployed on GCP Cloud Run (stateless, containerized)
- Flutter built for web for MVP; mobile is future scope
