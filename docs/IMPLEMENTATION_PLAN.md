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
  *(Phase 1 estimate; Phase 4 Hybrid live AMap Web key branch)*
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
Map: HybridMapProvider + EstimateMapProvider; AMap REST live when mapWebKey set and demoFixtures OFF.
Passenger point search/map-pick deferred; Phase 1 uses coords + fixtures + optional GPS for driver.
Verify: cd domain && npm test (15 pass as of Phase 2 grounding tests). DevEco Preview used for ArkTS UI smoke.
Phase 1 complete for offline path. Missing Map SDK is intentional, not a blocker for Phase 1/2 exit.
```

---

## Phase 2 — AI agent layer

**Goal:** Chat + tool loop produces the same grounded plans, with explanations and constraint refinement.

### LLM client

- [x] OpenAI-compatible client (chat completions)
- [x] Mode A user key / Mode B proxy base URL / Mode C disable
- [x] Timeouts, error mapping, cancellation on screen leave
- [x] Do not log secrets

### Tools (registry)

Implement handlers (names may be camelCase in code):

- [x] `getScenarioSnapshot` → `get_scenario_snapshot`
- [x] `setConstraints` → `set_constraints`
- [x] `getDrivingRoute` → `get_driving_route`
- [x] `generateAndScorePlans` → `generate_and_score_plans`  ← domain engine
- [x] `reverseGeocode` → `reverse_geocode`
- [x] `searchPoiNear` → `search_poi_near` (best effort; estimate returns [])
- [x] `formatShareText` → `format_share_text`

### Orchestrator

- [x] System prompt per `docs/AI_AGENT.md`
- [x] Bounded loop (`maxToolIters = 6`)
- [x] Tool trace persistence on turn
- [x] Grounding validator: final choice must reference engine IDs
- [x] Fallback to engine-only on LLM failure

### UI

- [x] Chat panel (composer + message list)
- [x] Plan cards can attach under an agent answer
- [x] “决策过程” debug bottom sheet (tool names + timings; hide secrets)
- [x] Settings: test LLM connection button (optional ping)

### Exit criteria

- [x] With a valid key, user can type a constraint-rich request and get a grounded plan.  
  *(Requires Mode A/B config + network; code path wired; live vendor call is device-side.)*
- [x] Without a key, form planning still works.
- [x] Validator rejects hallucinated candidate IDs in tests with mock LLM.  
  *(Pure domain tests: `domain/test/agent.test.ts` — no live LLM.)*

### Phase 2 notes

```
LLM client: entry/.../services/llm/OpenAiCompatibleClient.ets
  - Mode A: llmBaseUrl + llmApiKey + model → POST {base}/v1/chat/completions
  - Mode B: proxyBaseUrl (no device vendor key)
  - Mode C / misconfig / HTTP error → engine offline path
  - timeout default 25s; cancel on ChatPage aboutToDisappear
  - never logs Authorization / apiKey

Tools: entry/.../services/agent/ToolHost.ets (registry-only dispatch)
Orchestrator: AgentOrchestrator.ets (max 6 tool iters)
Grounding: stayPut | suggestion:N; validateOrFallbackPlanId rejects unknowns
Portable tests: domain/src/agent/* + domain/test/agent.test.ts (15 domain tests total)
UI: pages/ChatPage.ets — fixtures, quick prompts, plan mini-cards, 决策过程 toggle
Settings: 测试 LLM 连接 (ping)
Home: 智能助手规划 → ChatPage; 表单规划 → PlanPage
Default demo model hint: deepseek-chat (D3 still open for contest day)
Hybrid ready; Phase 4 enables live AMap when key present
```

---

## Phase 3 — Session lock, share, practical constraints

**Goal:** Turn a recommendation into a **locked** trip plan the user can execute and share. Still **one device**, still **no auto mid-trip meeting changes**.

### Session

- [x] `TripSession` state machine: `planning → confirmed → closed`
- [x] Confirm action freezes selected meeting point + polylines + ETAs snapshot
- [x] Explicit **Re-plan** creates a new planning attempt (does not mutate locked session; archives or closes old)
- [x] In-memory session store (persist optional)

### Share & navigate

- [x] Clipboard share text (zh-CN template): meeting name, coords, both ETAs, mode, short why
- [x] Open in Maps: system/map deep link strategy for HarmonyOS (document chosen schemes)
- [x] Web fallback map link if app scheme unavailable

### Practical quality upgrades

- [x] Apply UI + chat constraints end-to-end (`maxPassengerWalkMin`, `avoidTransit`, allow-list)
- [x] Reverse-geocode meeting point for human names
- [x] Optional: snap meeting label to nearby POI name without moving coordinates beyond a small radius policy (document policy)
- [x] Confidence / dataSource surfaces on locked session screen
- [x] Empty states: missing passenger point, equal points, zero candidates

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
Session:
  - domain/src/session.ts + entry/.../services/session/SessionLogic.ets
    createPlanningSession / confirmSession / closeSession / resolveLockedPlan
  - TripSessionStore (in-memory): planning + locked + archived closed copies
  - Re-plan closes locked (archive) and clears planning; never mutates locked fields
  - LockedSessionPage reads TripSessionStore.getLocked()

Share text:
  - formatShareText (OfflineReply) — zh-CN clipboard payload
  - ShareService.copyText via pasteboard
  - Example:
    【会合助手】会合方案
    乘客方式：骑行
    会合点：…
    坐标：108.xxxxx, 34.xxxxx
    司机 ETA：约 N 分钟
    乘客 ETA：约 M 分钟
    会合完成：约 T 分钟
    说明：…
    数据：估算

Map open schemes (Settings.mapApp, default browser):
  - amap:   androidamap://viewMap?sourceApplication=MeetAgent&poiname=&lat=&lon=&dev=0
  - baidu:  baidumap://map/marker?location=lat,lon&title=&coord_type=gcj02&src=MeetAgent
  - apple:  http://maps.apple.com/?ll=lat,lon&q=
  - browser / fallback: https://uri.amap.com/marker?position=lon,lat&name=
  - App scheme failure → web fallback toast
  - Coords treated as GCJ-02 end-to-end

POI snap policy (name only):
  - DEFAULT_POI_SNAP_RADIUS_M = 80
  - Accept POI name only if haversine ≤ 80 m; never move coordinates
  - Estimate MapProvider returns empty POI list → label stays reverse-geocode / coord text
  - Confirm path best-effort reverseGeocode when name empty (estimate → lat,lon string)

UI:
  - PlanPage + ChatPage: 确认并锁定 → LockedSessionPage
  - Share / 打开地图 wired (no longer Phase 3 placeholders)
  - Empty hints: missing passenger, equal points, zero move candidates
  - Constraints already engine-enforced (allowedModes, avoidTransit, maxPassengerWalkMin)
  - Home: fixed-height scrollable sheet + map stage; driver/passenger mode chip (header UR, expand menu)
  - Immersive dark window (EntryAbility full-screen + start_window #07080C); AppLayout.statusBarInsetVp for headers
  - Remaining 即将接入: JP l10n (Phase 4 optional)

Verify: cd domain && npm test → 20 pass (incl. session machine)
Device: emulator Run exercised lock/share/clipboard; location 3301100 = no GPS fix (enable simulation)
Live AMap REST delivered in Phase 4; Mode C offline fixtures remain demo path.
```

---

## Phase 4 — Contest polish & hardening

**Goal:** Reliable stage demo + readable submission quality + **live AMap Hybrid** for real routes.

### Live map / calculation engine

- [x] `AmapWebMapProvider` Web REST (driving / walking / bicycling / transit + regeo + place/text)
- [x] `HybridMapProvider` live branch + estimate fallback + honest `dataSource`
- [x] `PlanningService.createProvider(mapWebKey, forceEstimate)` — demoFixtures forces estimate
- [x] Wire Plan + Chat + agent tools through Hybrid
- [x] Home interactive AMap JS map (drag/zoom/traffic) + search-first assign sheet
- [x] POI / place labels via regeo (UI never shows bare lat/lon as primary text)
- [x] Plan + Chat result maps show routes; card select updates polylines
- [x] Loading / error recovery copy during route fetch
- [x] Pure polyline decode helpers + unit tests (`domain/src/amapPolyline.ts`)
- [x] Device path exercised with Map Web Key (live basemap + routes + traffic)

### Demo reliability

- [x] `fixtures/scenarios/*.json` ≥ 2 realistic city scenarios (西安 / 上海)
- [x] Optional recorded route sample `fixtures/routes/xian-driving-sample.json`
- [x] Demo mode switch: force fixture/estimate provider (`demoFixtures`)
- [x] `docs/DEMO_SCRIPT.md` matches real buttons (确认并锁定 / 复制分享 / 打开地图 / 模式 chip)

### UX polish

- [x] Loading progress copy during plan / tool path (“正在获取驾车路线…”)
- [x] Error toasts with recovery (retry / demo fixtures / open settings)
- [ ] Basic motion (page transitions) without jank on mid devices
- [ ] App name, icons, about screen
- [x] zh-CN copy review for map/demo paths; EN deferred
- [ ] JP l10n still deferred (`即将接入`)

### Quality

- [x] Engine tests green (`cd domain && npm test` → 25 pass)
- [x] Agent grounding tests green
- [x] Manual test checklist in `tests/MANUAL_CHECKLIST.md` (live + offline)
- [x] README quick start accurate (keys, DevEco, offline/live/LLM)
- [x] Architecture notes match Hybrid + AMap modules

### Optional thin proxy

- [ ] `server/` OpenAI-compatible forwarder
- [ ] Env-based vendor key
- [ ] CORS not required if phone hits server directly; document LAN IP usage for demo
- [ ] Health endpoint

### Exit criteria

- Cold demo succeeds twice in a row on target phone. *(device — human)*
- Mode C demo succeeds with airplane-mode-ish network assumptions (fixtures). *(code path ready)*
- Docs sufficient for another teammate to run without chat history. *(updated this phase)*

### Phase 4 notes

```
Live map (2026-07-25, updated):
  - entry/.../services/map/AmapWebMapProvider.ets — restapi.amap.com/v3
    GET direction/driving|walking|bicycling, direction/transit/integrated,
    geocode/regeo (POI-preferring labels), place/text
  - HybridMapProvider: mapWebKey + !demoFixtures → live; failure → estimate
    with dataSource live_with_fallback
  - PlanningService.createProvider(key, forceEstimate=settings.demoFixtures)
  - Home Index: InteractiveMapView (AMap JS basemap + traffic) + search-first
    assign sheet (driver/passenger by mode) → TripDraftStore
  - PlanPage 普通规划: draft-first read-only points; result map + card routes;
    meeting place regeo label (no bare coords UI)
  - ChatPage 智能助手: draft intro POI names; plan cards + interactive map
  - domain/src/amapPolyline.ts + tests (decode / merge / routePoints)
  - fixtures/routes/xian-driving-sample.json optional recorded sample
  - Keys only in preferences / local .env — never git
  - GCJ-02 end-to-end; AMap JS Web basemap (Map Kit not required)
  - Verify domain: npm test 25 pass. DevEco Run for HTTP + Web map.
```

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

- [x] HarmonyOS HAP runs on phone
- [x] Plan from two points with multi-modal options
- [x] AI chat path works with user key (or proxy)
- [x] Offline engine path works without LLM
- [x] Confirm locks plan; no auto meeting-point change
- [x] Share + open maps
- [x] Fixture demo path
- [x] Docs + AGENTS.md consistent with code
- [x] Live AMap Hybrid (device key still required for live badge)

---

## Open decisions log

| ID | Decision | Status | Notes |
| --- | --- | --- | --- |
| D1 | Map provider | Closed | Hybrid: Estimate always; AMap Web HTTP when mapWebKey present and demoFixtures OFF |
| D2 | Domain language packaging into ArkTS | Closed (Phase 1) | Mirrored ArkTS port under `entry/src/main/ets/domain/`; pure TS tests in `domain/` |
| D3 | LLM default model for demo | Soft default | AppSettings default `deepseek-chat` + `https://api.deepseek.com`; contest day may switch model/proxy (D4) |
| D4 | Proxy hosting for contest day | Open | Local laptop hotspot vs cloud |

Update this table when decisions close.
