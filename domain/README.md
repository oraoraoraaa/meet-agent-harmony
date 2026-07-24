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
| `src/index.ts` | public exports |

## Rules

- No ArkUI imports.
- No LLM calls.
- No secret material.
- Pure functions preferred; inject IO via interfaces.

## Packaging into Harmony app

ArkTS cannot import this Node package directly. Phase 1 keeps a **mirrored port** under
`entry/src/main/ets/domain/` (and services that call it). Keep contracts aligned with
`src/models.ts` / engine defaults when either side changes.

## Commands

```bash
cd domain
npm test
# optional if typescript is installed:
# npx tsc -p tsconfig.json --noEmit
```

## Status

Phase 1 engine implemented with estimate providers + unit tests.
