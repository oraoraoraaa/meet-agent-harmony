# Domain core

Portable, UI-free planning logic for MeetAgent.

## Contents

| Path | Role |
| --- | --- |
| `src/models.ts` | Geo / scenario / recommendation / session types |
| `src/engineConfig.ts` | Tunable constants |
| `src/geo.ts` | haversine and small geo helpers |
| `src/estimate.ts` | Straight-line route + speed-model ETAs |
| `src/engine.ts` | candidates, scoring, ranking, stay-put decision |
| `src/runAnalysis.ts` | orchestrate route + ETAs → `RecommendationSet` |
| `src/agent/` | grounding, tool catalog, offline reply, offline orchestrator helpers |
| `src/index.ts` | public exports |

## Rules

- No ArkUI imports.
- No secret material.
- Pure functions preferred; inject IO via interfaces.
- LLM HTTP clients live in the app (`entry/.../services/llm/`), not here.
- Agent grounding / offline reply helpers are pure and unit-tested here.

## Packaging into Harmony app

ArkTS cannot import this Node package directly. Keep a **mirrored port** under
`entry/src/main/ets/domain/` (engine) and `entry/src/main/ets/services/agent/`
(agent runtime). Keep contracts aligned when either side changes.

## Commands

```bash
cd domain
npm test
# optional if typescript is installed:
# npx tsc -p tsconfig.json --noEmit
```

## Status

Phase 1 engine + Phase 2 agent grounding helpers implemented with unit tests.
