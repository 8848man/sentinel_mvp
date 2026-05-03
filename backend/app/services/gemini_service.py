import json
import asyncio
import google.generativeai as genai
from app.core.config import settings

genai.configure(api_key=settings.GEMINI_API_KEY)
_model = genai.GenerativeModel(settings.GEMINI_MODEL)

METADATA_PROMPT = """
You are an incident management assistant.
Analyze the following error log or description and extract structured metadata.

Log input:
---
{log_text}
---

Respond ONLY with valid JSON matching this schema (no markdown, no explanation):
{{
  "suggested_title": "short incident title (max 60 chars)",
  "suggested_severity": "critical or major or minor",
  "detected_components": ["list", "of", "tech", "components"],
  "description": "one-sentence summary of the issue"
}}

Severity rules:
- critical: service down, data loss risk, P0 impact
- major: degraded performance, significant user impact
- minor: low impact, background job issues

Detect components mentioned or implied (PostgreSQL, Redis, AWS EKS, Spring Boot, Nginx, Kafka, etc).
""".strip()

ANALYSIS_PROMPT = """
You are an expert SRE AI assistant analyzing a production incident.

Incident: {title}
Severity: {severity}
Affected components: {components}

Error logs:
---
{log_text}
---

Known similar past incidents (for context only):
{similar_context}

Respond ONLY with valid JSON (no markdown, no explanation):
{{
  "root_cause": "detailed root cause explanation (2-4 sentences)",
  "confidence": 0.87,
  "impact_summary": "one-sentence impact description",
  "fix_flows": [
    {{
      "title": "action-oriented fix flow name",
      "confidence": 0.96,
      "checklist_items": ["Step 1 description", "Step 2 description"]
    }}
  ],
  "similar_incident_codes": []
}}

Rules:
- Provide 3-5 fix flows ordered by confidence descending
- Each fix flow must have 2-5 checklist steps
- confidence is float 0.0-1.0
- similar_incident_codes: max 3, from provided context only
""".strip()


def _parse_json(text: str) -> dict:
    clean = text.strip()
    if clean.startswith("```"):
        clean = clean.split("\n", 1)[-1].rsplit("```", 1)[0]
    return json.loads(clean)


async def extract_metadata(log_text: str) -> dict:
    prompt = METADATA_PROMPT.format(log_text=log_text)
    try:
        response = await asyncio.wait_for(
            _model.generate_content_async(prompt),
            timeout=settings.GEMINI_TIMEOUT_SECONDS,
        )
        return _parse_json(response.text)
    except asyncio.TimeoutError:
        raise RuntimeError("Gemini API timeout")
    except json.JSONDecodeError:
        raise RuntimeError("Gemini returned invalid JSON")


async def analyze_incident(
    log_text: str,
    title: str,
    severity: str,
    components: list[str],
    similar_context: str = "None available.",
) -> dict:
    prompt = ANALYSIS_PROMPT.format(
        title=title,
        severity=severity,
        components=", ".join(components) or "Unknown",
        log_text=log_text,
        similar_context=similar_context,
    )
    try:
        response = await asyncio.wait_for(
            _model.generate_content_async(prompt),
            timeout=settings.GEMINI_TIMEOUT_SECONDS,
        )
        return _parse_json(response.text)
    except asyncio.TimeoutError:
        raise RuntimeError("Gemini API timeout")
    except json.JSONDecodeError:
        raise RuntimeError("Gemini returned invalid JSON")
