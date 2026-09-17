# HarmonyOS entry module

Open the repository root in DevEco Studio. `entry/` is the phone HAP module.

## Layout

- `src/main/ets/pages/`: home, form planning, chat, locked plan, settings.
- `src/main/ets/domain/`: pure ArkTS engine port; keep it aligned with `domain/`.
- `src/main/ets/common/`: settings models, theme, layout, glass components, reply formatting.
- `src/main/ets/services/map/`: Hybrid estimate/AMap REST routing and Web map rendering.
- `src/main/ets/services/agent/` and `llm/`: bounded tool loop, grounding, compatible HTTP client.
- `src/main/ets/services/session/`: in-memory draft, locked snapshot, share text.
- `src/main/ets/services/settings/`, `location/`, `planning/`: preferences, one-shot location, fixtures.
- `src/test/`: Hypium tests for the ArkTS engine port, also registered by `src/ohosTest/`.

## Current surfaces

Home supports map/search selection and assigning driver/passenger points. Form planning and
chat share Hybrid routing, result maps, and confirm/lock/share. Mode C works with estimated
routes and an offline schematic Web map. Live routing uses AMap REST when a Web key is set
(with automatic estimate fallback on failure). The basemap uses AMap JavaScript through ArkWeb; no native
map SDK is bundled. The optional proxy remains a contract, not an implemented server.

Keys are stored in device-local Preferences; hardware-backed secret storage is still pending.
Never commit keys or signing configuration. Build commands are in the root README.

See [performance notes](../docs/PERFORMANCE.md) for map refresh ownership and validation.
DevEco Preview cannot render the Web map; actual first paint and interaction require a device.
