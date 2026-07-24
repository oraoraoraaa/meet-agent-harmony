# HarmonyOS application (`app/`)

This directory will hold the **DevEco Studio** HarmonyOS project (Stage model, ArkTS/ArkUI).

## Status

**Not scaffolded by DevEco yet.** Phase 0 of `docs/IMPLEMENTATION_PLAN.md` creates the real project here.

Until then, keep platform-agnostic planning logic in `../domain/` and product contracts in `../docs/`.

## Target structure (after DevEco generate)

```text
app/
  AppScope/
  entry/
    src/main/ets/
      entryability/
      pages/
      features/
      services/
    src/main/resources/
  oh-package.json5
  build-profile.json5
  ...
```

## Feature map (logical)

| Feature | Responsibility |
| --- | --- |
| home | Entry, start planning |
| chat | Agent conversation UI |
| map_plan | Map + results cards |
| session | Confirmed locked plan |
| settings | Keys, LLM mode, prefs |

## Rules

- Do not commit signing materials or API keys.
- Call `domain` engine for scores; do not reimplement scoring in UI files.
- Agent tools live under services; keep pages thin.
