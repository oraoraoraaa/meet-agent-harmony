# HarmonyOS app module notes

The **DevEco / HarmonyOS project lives at the repository root**, not under a nested `app/` folder.

## Key paths

| Path | Role |
| --- | --- |
| `AppScope/` | App-level bundle id, icon, label |
| `entry/` | Main HAP module (ArkTS UI, abilities, resources) |
| `entry/src/main/ets/pages/` | UI pages |
| `entry/src/main/ets/entryability/` | UIAbility entry |
| `build-profile.json5` | Products, SDK versions, modules |
| `oh-package.json5` | OHPM dependencies |
| `hvigorfile.ts` | Build entry |
| `local.properties` | **Local only** (gitignored); DevEco regenerates |

## Feature code placement (as we build)

Prefer under `entry/src/main/ets/`:

```text
entry/src/main/ets/
  pages/
  features/
    home/
    chat/
    map_plan/
    session/
    settings/
  services/
    agent/
    llm/
    map/
    location/
    share/
  common/
```

Pure planning math stays in repo-root `domain/` (portable TS). Wire/port into ArkTS as decided in Phase 1 (see `docs/IMPLEMENTATION_PLAN.md` decision D2).

## Do not commit

- `local.properties`
- `.idea/`, `.hvigor/`, `oh_modules/`, `**/build/`
- API keys
