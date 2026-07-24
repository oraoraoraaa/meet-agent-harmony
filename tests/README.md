# Tests

| Layer | Location | How |
| --- | --- | --- |
| Domain unit | `domain/test/` | `cd domain && npm test` (Node built-in test runner) |
| App UI smoke | `entry/` | DevEco / device manual |
| Agent grounding | TBD under `entry` or `domain` | Mock LLM + mock tools |
| Manual stage | `tests/MANUAL_CHECKLIST.md` | Human |

Do not rely on live map/LLM in unit tests.
