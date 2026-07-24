# Implementation Plan (Plan B · Session AI Agent)

This is the **delivery source of truth** for building MeetAgent.

**Product posture (v1):**

- HarmonyOS phone app with AI tool-using agent + local engine
- Meeting plan decided **once at the beginning**
- After confirm, meeting point is **locked** (no automatic changes)
- **No dual-phone sync** in v1
- LLM via user key and/or optional proxy; offline engine always works

Track progress by checking boxes as work lands. Add short implementation notes under each phase when decisions crystallize.

---

## Guiding principles (do not violate)

1. Numbers from tools/engine only; LLM explains and coordinates.
2. Mode C offline planning always works.
3. Small vertical slices that stay demoable.
4. Domain logic pure and unit-tested.
5. Secrets never committed.

---

## Phase 0 — Repository & platform foundation

**Goal:** Empty repo becomes a runnable HarmonyOS shell with config surfaces and a chosen map strategy.

### Tasks

- [x] Initialize git-friendly layout (`domain/`, `server/`, `fixtures/`, `docs/`, `tests/`)
- [x] Human `README.md` + AI `AGENTS.md` + product docs
- [x] Integrate DevEco HarmonyOS Stage application at **repo root** (`AppScope/`, `entry/`, hvigor, oh-package)
- [x] Document “open repo root in DevEco” workflow in `README.md` / `entry/README.md`
- [x] Wire first device/preview run (Phase 0 shell verified in DevEco preview)
- [x] Settings screen skeleton: map key slots, LLM baseUrl/key/model, proxy toggle, language
- [x] Preferences-backed settings store for keys (device-local; not full hardware keystore yet)
- [x] **Map provider spike** (time-box 1–2 days):
  - Option H: Harmony Map Kit (routing/POI capability matrix)
  - Option A: AMap Harmony SDK / Web service hybrid
  - Record decision in this file under “Phase 0 notes”
- [x] Location permission happy path (request → read once → show status; deny still OK)
- [x] Network permission declared (`ohos.permission.INTERNET`) for later map/LLM HTTP
- [x] CI-less local checklist: install/preview, open settings, save keys, locate once

### Exit criteria

- [x] App installs on a HarmonyOS phone or official emulator.
- [x] Settings can store and reload fake keys.
- [x] Map provider decision written down.
- [x] No crash on first launch without keys.

### Phase 0 notes

```
DevEco project location: repository root (/Users/rinalic/Local/Github/meet-agent-harmony)
Bundle name: com.rinalic.meetAgentHarmony
Entry module: entry/
Generator seed (do not treat as source of truth): ~/DevecostudioProjects/meet_agent_harmony
Preview verified: Phase 0 shell (MeetAgent / 会合助手 · HarmonyOS)
Settings: entry/src/main/ets/pages/SettingsPage.ets + preferences store
Location: one-shot request via LocationKit; denial does not block app

Map provider decision: Hybrid — EstimateMapProvider first + optional AMap Web HTTP when mapWebKey present
Date: 2026-07-24
Rationale:
  - Mode C offline must always plan without vendor SDK install friction.
  - AMap Web REST (driving/walking/bicycling/transit + regeo/POI) covers quantitative tools
    behind a single MapProvider interface; coordinates treated as GCJ-02 end-to-end.
  - Harmony Map Kit remains a later option for on-map rendering only; not required for
    Phase 1 ranking (schematic polyline preview is enough).
Implications for routing APIs:
  - entry/services/map/MapProvider.ets is the only app-facing surface.
  - Live: AmapWebMapProvider (HTTP) when mapWebKey set; else EstimateMapProvider.
  - Failures degrade to estimate + dataSource badge (estimate / live_with_fallback / live).
  - No vendor SDK binary committed; keys only in preferences.
```

---

## Phase 1 — Deterministic planning core + plan UI

**Goal:** Two points in → ranked multi-modal plans out, without any LLM.

### Domain (`domain/`)

- [x] Types: `GeoPoint`, `NamedPoint`, `MobilityMode`, `Scenario`, `Constraints`, `RoutePoint`, `Candidate`, `EvaluatedOption`, `Suggestion`, `StayPutSuggestion`, `RecommendationSet`, `TripSession`
- [x] `EngineConfig` with defaults:
  - `maxCandidates = 4`
  - `minCandidateSpacingM = 250`
  - `minPassengerMoveM = 120`
  - `walkReachM = 1200`
  - `bicycleReachM = 3500`
  - `transitReachM = 8000`
  - `transitMinM = 2000`
  - `minDriverSavingSecs = 60`
  - `passengerBurdenWeight = 0.15`
  - `bicyclePenaltyMin = 1.0`
  - `transitPenaltyMin = 2.5`
  - `minImprovementMin = 1.5`
- [x] `haversineM`
- [x] `generateRouteCandidates`
- [x] `reachableModes`
- [x] `scoreOption` / `rankOptions` / `bestPerMode` / `decideStayPut` (`decideSwitch`)
- [x] `runAnalysis` orchestrator interface (inject route + passenger ETA providers)
- [x] Estimate providers (no network): straight route + speed model
  - walk ~4.5 km/h, bicycle ~12 km/h, transit effective ~20 km/h (tunable)
- [x] Unit tests for invariants (spacing, reach, threshold, per-mode reduction)

### Entry module services (`entry/src/main/ets/services/`)

- [x] Map/routing provider interface:
  - `getDrivingRoute(from, to)`
  - `getPassengerPath(mode, from, to, city?)`
  - `reverseGeocode(point)`
  - `searchPoi(query, near?)` (stub)
- [x] Live implementation behind interface (per Phase 0 decision) + estimate fallback  
  *(Phase 1: estimate always; HybridMapProvider reserved for AMap Web key branch)*
- [x] `PlanningService.plan(scenario) -> RecommendationSet`

### UI

- [x] Home / plan form:
  - driver start (default GPS or manual)
  - passenger point (search or map pick)
  - mode allow-list toggles
  - **Plan** button
- [x] Results:
  - map polylines (driver solid, passenger dashed)
  - cards: recommended + alternatives including stay-put
  - dataSource badge (`实时` / `实时+估算` / `估算`)
  - loading / error / retry
- [x] Select a card to preview that option’s geometry

### Exit criteria

- [x] Fixture scenario produces stable multi-option output in estimate mode.
- [x] Live mode works when keys present (or documented partial).  
  *(Documented partial: live HTTP not yet wired; estimate always works.)*
- [x] Unit tests for engine pass.
- [x] User can select an option (not yet locked session).

### Phase 1 notes

```
D2 packaging: mirrored ArkTS port under entry/src/main/ets/domain/* (pure TS stays in domain/).
Coordinate system: treat lon/lat as GCJ-02 when using China map vendors; estimate uses same numbers.
Estimate speeds: drive 28 / walk 4.5 / bike 12 / transit 20 km/h.
UI: pages/PlanPage.ets — fixtures 西安/上海, schematic polyline preview (no Map Kit), 估算 badge.
Map: HybridMapProvider + EstimateMapProvider; AMap REST deferred until mapWebKey live path is needed.
Passenger point search/map-pick deferred; Phase 1 uses coords + fixtures + optional GPS for driver.
Verify: cd domain && npm test (9 pass). DevEco Preview used for ArkTS UI smoke.
Phase 1 complete for offline path. Missing Map SDK is intentional, not a blocker for Phase 1 exit.
```

---

## Phase 2 — AI agent layer

**Goal:** Chat + tool loop produces the same grounded plans, with explanations and constraint refinement.

### LLM client

- [ ] OpenAI-compatible client (chat completions)
- [ ] Mode A user key / Mode B proxy base URL / Mode C disable
- [ ] Timeouts, error mapping, cancellation on screen leave
- [ ] Do not log secrets

### Tools (registry)

Implement handlers (names may be camelCase in code):

- [ ] `getScenarioSnapshot`
- [ ] `setConstraints`
- [ ] `getDrivingRoute`
- [ ] `generateAndScorePlans`  ← domain engine
- [ ] `reverseGeocode`
- [ ] `searchPoiNear` (best effort)
- [ ] `formatShareText`

### Orchestrator

- [ ] System prompt per `docs/AI_AGENT.md`
- [ ] Bounded loop (`maxToolIters = 6`)
- [ ] Tool trace persistence on turn
- [ ] Grounding validator: final choice must reference engine IDs
- [ ] Fallback to engine-only on LLM failure

### UI

- [ ] Chat panel (composer + message list)
- [ ] Plan cards can attach under an agent answer
- [ ] “决策过程” debug bottom sheet (tool names + timings; hide secrets)
- [ ] Settings: test LLM connection button (optional ping)

### Exit criteria

- With a valid key, user can type a constraint-rich request and get a grounded plan.
- Without a key, form planning still works.
- Validator rejects hallucinated candidate IDs in tests with mock LLM.

### Phase 2 notes

```
(model choices, prompt versions)
```

---

## Phase 3 — Session lock, share, practical constraints

**Goal:** Turn a recommendation into a **locked** trip plan the user can execute and share. Still **one device**, still **no auto mid-trip meeting changes**.

### Session

- [ ] `TripSession` state machine: `planning → confirmed → closed`
- [ ] Confirm action freezes selected meeting point + polylines + ETAs snapshot
- [ ] Explicit **Re-plan** creates a new planning attempt (does not mutate locked session; archives or closes old)
- [ ] In-memory session store (persist optional)

### Share & navigate

- [ ] Clipboard share text (zh-CN template): meeting name, coords, both ETAs, mode, short why
- [ ] Open in Maps: system/map deep link strategy for HarmonyOS (document chosen schemes)
- [ ] Web fallback map link if app scheme unavailable

### Practical quality upgrades

- [ ] Apply UI + chat constraints end-to-end (`maxPassengerWalkMin`, `avoidTransit`, allow-list)
- [ ] Reverse-geocode meeting point for human names
- [ ] Optional: snap meeting label to nearby POI name without moving coordinates beyond a small radius policy (document policy)
- [ ] Confidence / dataSource surfaces on locked session screen
- [ ] Empty states: missing passenger point, equal points, zero candidates

### Explicitly not in this phase

- Dual-phone sync
- Background periodic re-meeting-point updates
- Push notifications to counterparty

### Exit criteria

- Confirm → locked session screen with share + open maps.
- Re-plan is user-initiated only.
- Constraint toggles change available suggestions.
- Demo path works on device offline (fixture) and online (keys).

### Phase 3 notes

```
(share payload example, map scheme list)
```

---

## Phase 4 — Contest polish & hardening

**Goal:** Reliable stage demo + readable submission quality.

### Demo reliability

- [ ] `fixtures/scenarios/*.json` ≥ 2 realistic city scenarios
- [ ] Optional recorded route fixture to avoid live flakiness on stage
- [ ] Demo mode switch: force fixture provider
- [ ] `docs/DEMO_SCRIPT.md` timed to ~3 minutes

### UX polish

- [ ] Loading skeletons / progress copy during tool calls (“正在获取驾车路线…”)
- [ ] Error toasts with recovery actions
- [ ] Basic motion (page transitions) without jank on mid devices
- [ ] App name, icons, about screen
- [ ] zh-CN copy review; EN if time

### Quality

- [ ] Engine tests green
- [ ] Agent grounding tests green
- [ ] Manual test checklist in `tests/MANUAL_CHECKLIST.md`
- [ ] README quick start accurate to actual DevEco steps
- [ ] Architecture diagram matches code modules

### Optional thin proxy

- [ ] `server/` OpenAI-compatible forwarder
- [ ] Env-based vendor key
- [ ] CORS not required if phone hits server directly; document LAN IP usage for demo
- [ ] Health endpoint

### Exit criteria

- Cold demo succeeds twice in a row on target phone.
- Mode C demo succeeds with airplane-mode-ish network assumptions (fixtures).
- Docs sufficient for another teammate to run without chat history.

---

## Cross-cutting work (any phase)

| Item | Rule |
| --- | --- |
| Coordinate system | Document as GCJ-02 if using China map vendors; keep one system end-to-end |
| Logging | Info-level tool names + durations; never keys |
| Feature flags | `llmEnabled`, `demoFixtures`, `verboseAgentTrace` |
| Performance | Cap candidates; avoid unbounded POI queries |
| Accessibility | Readable contrast on plan cards |

---

## Suggested calendar (single developer, indicative)

| Week | Focus |
| --- | --- |
| Week 1 | Phase 0 + Phase 1 domain |
| Week 2 | Phase 1 UI + live map provider |
| Week 3 | Phase 2 agent |
| Week 4 | Phase 3 lock/share + Phase 4 polish |

Compress only by cutting live POI snap and EN l10n, not by cutting Mode C or grounding.

---

## Definition of done (v1 product)

- [ ] HarmonyOS HAP runs on phone
- [ ] Plan from two points with multi-modal options
- [ ] AI chat path works with user key (or proxy)
- [ ] Offline engine path works without LLM
- [ ] Confirm locks plan; no auto meeting-point change
- [ ] Share + open maps
- [ ] Fixture demo path
- [ ] Docs + AGENTS.md consistent with code

---

## Open decisions log

| ID | Decision | Status | Notes |
| --- | --- | --- | --- |
| D1 | Map provider | Closed | Hybrid: EstimateMapProvider always; AMap Web HTTP when mapWebKey present (live REST deferred) |
| D2 | Domain language packaging into ArkTS | Closed (Phase 1) | Mirrored ArkTS port under `entry/src/main/ets/domain/`; pure TS tests in `domain/` |
| D3 | LLM default model for demo | Open | Prefer low-latency CN-accessible model |
| D4 | Proxy hosting for contest day | Open | Local laptop hotspot vs cloud |

Update this table when decisions close.
