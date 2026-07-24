# Tests

| Layer | Location | How |
| --- | --- | --- |
| Domain unit | `domain/test/` | `cd domain && npm test` (Node built-in test runner) |
| Agent grounding | `domain/test/agent.test.ts` | Mock-free pure checks: hallucinated IDs rejected; offline turn grounded |
| App UI smoke | `entry/` | DevEco / device manual |
| Manual stage | `tests/MANUAL_CHECKLIST.md` | Human |

Do not rely on live map/LLM in unit tests.
