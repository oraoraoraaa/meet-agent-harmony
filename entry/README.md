# entry module notes

DevEco opens the **repository root**. This module is the main HAP.

## Layout

```text
entry/src/main/ets/
  common/           # AppSettings, AppTheme, GlassChrome, PolylineMath
  domain/           # ArkTS mirror of repo-root domain/ engine
  pages/            # Index, PlanPage, SettingsPage
  services/
    settings/       # Preferences-backed SettingsStore
    location/       # one-shot LocationService
    map/            # MapProvider + PlanningService (estimate Mode C)
    planning/       # FixtureCatalog
    agent/          # (Phase 2)
    llm/            # (Phase 2)
  entryability/
  entrybackupability/
```

## Phase 1 surfaces

- Home: liquid-glass stage shell → plan entry, settings, one-shot locate
- Plan: fixtures + coords + mode constraints → offline RecommendationSet + cards
- Settings: map keys, LLM mode A/B/C fields, language, fixture/trace toggles
- Permissions: INTERNET, LOCATION, APPROXIMATELY_LOCATION

## Map status

**No vendor Map SDK in Phase 1.** Planning uses the estimate engine (straight-line + speed model) via `EstimateMapProvider` / `HybridMapProvider` shell. Live AMap Web HTTP is intentionally deferred; keys can still be stored in Settings for later.

## Rules

- Do not commit keys.
- Pure planning math also lives in repo-root `domain/` (Node unit tests). Keep ArkTS `entry/.../domain/` contracts aligned.
