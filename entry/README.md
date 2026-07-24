# entry module notes

DevEco opens the **repository root**. This module is the main HAP.

## Layout

```text
entry/src/main/ets/
  common/           # AppSettings, AppTheme, GlassChrome, PolylineMath, ReplyFormat
  domain/           # ArkTS mirror of repo-root domain/ engine
  pages/            # Index, ChatPage, PlanPage, SettingsPage
  services/
    settings/       # Preferences-backed SettingsStore
    location/       # one-shot LocationService
    map/            # MapProvider + PlanningService (estimate Mode C)
    planning/       # FixtureCatalog
    agent/          # orchestrator, tools, grounding, offline reply
    llm/            # OpenAI-compatible client (Mode A/B)
  entryability/
  entrybackupability/
```

## Surfaces (through Phase 2)

- Home: liquid-glass stage shell → chat / form plan / settings / one-shot locate
- Chat: agent tool loop or offline engine; plan mini-cards; 决策过程 trace
- Plan: fixtures + coords + mode constraints → offline RecommendationSet + schematic polylines
- Settings: map keys, LLM mode A/B/C, test LLM ping, language, fixture/trace toggles
- Permissions: INTERNET, LOCATION, APPROXIMATELY_LOCATION

## Map status

**No vendor Map SDK yet (intentional).** Planning uses the estimate engine
(straight-line + speed model) via `EstimateMapProvider` / `HybridMapProvider` shell.
Live AMap Web HTTP is deferred; keys can still be stored in Settings for later.

## Rules

- Do not commit keys.
- Pure planning math also lives in repo-root `domain/` (Node unit tests). Keep ArkTS `entry/.../domain/` contracts aligned.
- Do not commit half-working UI; verify Preview/device before committing (see root `AGENTS.md`).
