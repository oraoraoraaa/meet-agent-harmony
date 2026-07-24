# entry module notes

DevEco opens the **repository root**. This module is the main HAP.

## Layout

```text
entry/src/main/ets/
  common/           # AppSettings, DomainTypes
  pages/            # Index (home), SettingsPage
  services/
    settings/       # Preferences-backed SettingsStore
    location/       # one-shot LocationService
    agent/          # (Phase 2)
    llm/            # (Phase 2)
    map/            # (Phase 1)
  entryability/
  entrybackupability/
```

## Phase 0 surfaces

- Home: status summary, one-shot locate, entry to Settings
- Settings: map keys, LLM mode A/B/C fields, language, fixture/trace toggles
- Permissions declared: INTERNET, LOCATION, APPROXIMATELY_LOCATION

## Rules

- Do not commit keys.
- Prefer pure planning math in repo-root `domain/` (TS tests); port/call from here later.
