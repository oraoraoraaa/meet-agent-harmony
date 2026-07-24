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
- [ ] Wire debug signing / first device run (developer machine)
- [ ] Settings screen skeleton: map key slots, LLM baseUrl/key/model, proxy toggle, language
- [ ] Secure preferences helper for keys
- [ ] **Map provider spike** (time-box 1–2 days):
  - Option H: Harmony Map Kit (routing/POI capability matrix)
  - Option A: AMap Harmony SDK / Web service hybrid
  - Record decision in this file under “Phase 0 notes”
- [ ] Location permission happy path (request → read once → show on map or placeholder)
- [ ] Network security config as required by chosen SDKs
- [ ] CI-less local checklist: install, launch, open settings

### Exit criteria

- App installs on a HarmonyOS phone or official emulator.
- Settings can store and reload fake keys.
- Map provider decision written down.
- No crash on first launch without keys.

### Phase 0 notes

```
DevEco project location: repository root (/Users/rinalic/Local/Github/meet-agent-harmony)
Bundle name: com.rinalic.meetAgentHarmony
Entry module: entry/
Generator seed (do not treat as source of truth): ~/DevecostudioProjects/meet_agent_harmony

Map provider decision: (TBD after spike)
Date:
Rationale:
Implications for routing APIs:
```

---

## Phase 1 — Deterministic planning core + plan UI

**Goal:** Two points in → ranked multi-modal plans out, without any LLM.

### Domain (`domain/`)

- [ ] Types: `GeoPoint`, `NamedPoint`, `MobilityMode`, `Scenario`, `Constraints`, `RoutePoint`, `Candidate`, `EvaluatedOption`, `Suggestion`, `StayPutSuggestion`, `RecommendationSet`, `TripSession`
- [ ] `EngineConfig` with defaults:
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
- [ ] `haversineM`
- [ ] `generateRouteCandidates`
- [ ] `reachableModes`
- [ ] `scoreOption` / `rankOptions` / `bestPerMode` / `decideStayPut`
- [ ] `runAnalysis` orchestrator interface (inject route + passenger ETA providers)
- [ ] Estimate providers (no network): straight route + speed model
  - walk ~4.5 km/h, bicycle ~12 km/h, transit effective ~20 km/h (tunable)
- [ ] Unit tests for invariants (spacing, reach, threshold, per-mode reduction)

### Entry module services (`entry/src/main/ets/services/`)

- [ ] Map/routing provider interface:
  - `getDrivingRoute(from, to)`
  - `getPassengerPath(mode, from, to, city?)`
  - `reverseGeocode(point)`
  - `searchPoi(query, near?)` (can stub)
- [ ] Live implementation behind interface (per Phase 0 decision) + estimate fallback
- [ ] `PlanningService.plan(scenario) -> RecommendationSet`

### UI

- [ ] Home / plan form:
  - driver start (default GPS or manual)
  - passenger point (search or map pick)
  - mode allow-list toggles
  - **Plan** button
- [ ] Results:
  - map polylines (driver solid, passenger dashed)
  - cards: recommended + alternatives including stay-put
  - dataSource badge (`实时` / `实时+估算` / `估算`)
  - loading / error / retry
- [ ] Select a card to preview that option’s geometry

### Exit criteria

- Fixture scenario produces stable multi-option output in estimate mode.
- Live mode works when keys present (or documented partial).
- Unit tests for engine pass.
- User can select an option (not yet locked session).

### Phase 1 notes

```
(provider quirks, coordinate system GCJ-02 assumptions, etc.)
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
| D1 | Map provider | Open | Phase 0 spike |
| D2 | Domain language packaging into ArkTS | Open | Pure TS package vs duplicated ArkTS port — prefer single source if tooling allows |
| D3 | LLM default model for demo | Open | Prefer low-latency CN-accessible model |
| D4 | Proxy hosting for contest day | Open | Local laptop hotspot vs cloud |

Update this table when decisions close.
