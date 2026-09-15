# Tests

| Layer | Location | How |
| --- | --- | --- |
| Domain unit | `domain/test/` | `cd domain && npm test` (Node built-in test runner) |
| Agent grounding | `domain/test/agent.test.ts` | Mock-free pure checks: hallucinated IDs rejected; offline turn grounded |
| Map host lifecycle | `tests/map-lifecycle.test.mjs` | `node --test tests/map-lifecycle.test.mjs` (Node 22.13+; fake Web/timers) |
| ArkTS engine port | `entry/src/test/Engine.test.ets` | Hypium local/device suite (also registered in `ohosTest`) |
| Native map smoke | `entry/src/ohosTest/ets/test/MapSmoke.test.ets` | API-24 emulator/device; current map settings; use fixture mode for offline |
| App UI smoke | `entry/` | DevEco / device manual |
| Manual stage | `tests/MANUAL_CHECKLIST.md` | Human |

Do not rely on live map/LLM in unit tests.

Native performance validation and current tool limitations: [performance audit](../docs/PERFORMANCE.md).
