# Spec Authoring Rules

## Purpose

Specifications are implementation-oriented documents written for AI implementation agents (Claude Code, Cursor, Windsurf, etc.) — not analysis reports, not essays.

## Core Principle

Every spec must answer:

1. What needs to be built?
2. Why does it exist?
3. What constraints exist?
4. How should it be implemented?

Omit anything that doesn't contribute to one of these four.

## Document Size

| Tier | Lines |
|---|---|
| Target | 50–150 |
| Soft limit | 200 |
| Hard limit | 300 |

A doc over 200 lines must be split into multiple spec files.

## File Splitting

Split by responsibility, not by section. Example:

```
responsive_strategy.md
responsive_dashboard.md
responsive_workspace.md
responsive_archive.md
```

Avoid monolithic specs covering many screens/areas in one file.

## Writing Style

Prefer: bullet points, tables, requirement lists, implementation notes.

Avoid: narrative paragraphs, repeated explanations, historical context, analysis not tied to a build decision.

## Decision Recording

Record the decision and the requirement it produces. Skip justification text unless the reasoning changes the implementation (e.g., a constraint the agent must respect).

## Duplication

Never duplicate content across specs. Reference the other doc instead (e.g., `→ see 05_api_spec.md`).

## Recommended Structure

```md
# Summary

# Decisions

# Requirements

# Implementation Notes

# References
```

Not every section is mandatory — omit ones with nothing to say rather than padding them.

## AI Optimization

Optimize for machine readability, implementation clarity, and maintainability. Prefer several small linked documents over one large document.
