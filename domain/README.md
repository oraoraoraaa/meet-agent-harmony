# Domain core

Portable, UI-free planning logic for MeetAgent.

## Intended contents

| Path | Role |
| --- | --- |
| `src/models.ts` | Geo / scenario / recommendation / session types |
| `src/engineConfig.ts` | Tunable constants |
| `src/geo.ts` | haversine and small geo helpers |
| `src/engine.ts` | candidates, scoring, ranking, stay-put decision |
| `src/runAnalysis.ts` | orchestrate route + ETAs → `RecommendationSet` |
| `src/index.ts` | public exports |

## Rules

- No ArkUI imports.
- No LLM calls.
- No secret material.
- Pure functions preferred; inject IO via interfaces.

Packaging into the Harmony app (shared TS vs ArkTS port) is decided in Phase 0/1 — see `docs/IMPLEMENTATION_PLAN.md` open decision D2.

## Status

Scaffold only. Implementation starts in Phase 1.
