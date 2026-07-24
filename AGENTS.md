# AGENTS.md

Operating manual for **AI coding agents** (and humans pairing with them) in **MeetAgent / 会合助手**.

This file is the **operational source of truth** for how to work in this repository.  
Product vision lives in `docs/PRODUCT.md`. Delivery sequencing lives in `docs/IMPLEMENTATION_PLAN.md`.  
When docs and code disagree, **prefer the code**, then update the stale doc in the same change.

---

## What this project is

**MeetAgent** — HarmonyOS phone app + AI agent that plans a driver↔passenger **meeting strategy once at trip start**.

Pipeline:

1. User states a pickup need (chat and/or structured fields).
2. Agent interprets intent and constraints.
3. Deterministic tools fetch routes / generate candidates / score options.
4. Agent explains and helps the user pick one plan.
5. User confirms → share text / open maps.
6. Plan is **locked** for v1 (no automatic meeting-point mutation mid-trip).

Not a generic chatbot. Not a full ride-hailing network. Not a dual-phone realtime system in v1.

---

## Hard rules

1. **HarmonyOS client is the product surface.** Primary UI is ArkTS/ArkUI under `app/`. Do not introduce Flutter/React Native/Android-Java UI as the main app.
2. **LLM never invents ETAs, distances, or polylines.** All quantitative fields shown to users must come from tool/engine outputs. The model may only:
   - parse language into structured intent,
   - select among tool-returned candidate IDs,
   - explain grounded fields,
   - ask clarifying questions.
3. **Local engine must work without LLM.** Missing key / proxy / network → Mode C offline planning with template explanations.
4. **v1 plan lock.** After user confirms a meeting plan, do not auto-change the meeting point. Manual “re-plan” is allowed as an explicit user action. Dual-phone sync is out of scope for v1.
5. **No secrets in git.** No API keys, tokens, or private map credentials in source, fixtures committed for CI, or docs screenshots.
6. **Small, focused changes.** Match existing module boundaries. Prefer extending interfaces over parallel “v2” stacks.
7. **Graceful degradation is mandatory.** Map failure, route failure, POI failure, LLM failure → useful partial UI, never crash loops.
8. **Do not add dual-phone realtime, continuous auto re-meeting, or multi-agent negotiation** unless `docs/ROADMAP.md` is updated and a human explicitly asks.
9. **Prefer OpenAI-compatible LLM HTTP** (`baseUrl` + `apiKey` + `model`) so DeepSeek/Qwen/OpenAI/custom gateways all work.
10. **Keep domain pure.** Scoring / candidate generation / stay-put decision stay free of UI and free of raw HTTP where possible (`domain/`).

---

## Repository map

```text
app/        HarmonyOS application (DevEco project; ArkTS UI + platform services)
domain/     Portable models + interception engine + pure ranking logic
server/     Optional demo LLM proxy (not required for offline Mode C)
fixtures/   Canned scenarios & golden tool outputs for demos/tests
docs/       Product, architecture, AI, implementation plan, roadmap, demo script
tests/      Shared test notes / cross-layer cases
```

### Where to put new code

| Change type | Put it in |
| --- | --- |
| UI screens, navigation, Harmony permissions | `app/` |
| Geo types, scoring, candidate gen, plan models | `domain/` |
| LLM HTTP client, tool loop, prompts | `app/` agent layer and/or shared TS under `domain/agent` if pure |
| Map vendor SDK wrappers | `app/` services behind a provider interface |
| Demo key proxy | `server/` |
| Stage scenarios | `fixtures/` |
| Behavior contracts / phased tasks | `docs/` |

---

## Architecture agents must preserve

```text
UI (ArkUI)
  └─ Agent Orchestrator  (bounded tool loop)
        ├─ LLM provider (user key | proxy | disabled)
        ├─ Tools
        │    ├─ parse_intent (LLM-assisted)
        │    ├─ get_driving_route
        │    ├─ generate_candidates
        │    ├─ score_and_rank
        │    ├─ search_poi / reverse_geocode
        │    └─ format_plan
        └─ Local Engine (always available)
```

### Plan object (conceptual)

Every user-visible recommendation set should be representable as:

- `stayPut` plan (driver goes all the way to passenger)
- `suggestions[]` per passenger mode (walking / bicycle / transit) when reachable
- exactly one entry flagged `recommended` (stay-put **or** a mode suggestion)
- polylines + ETAs + meeting point + confidence/dataSource

### Decision rule (engine)

Default objective (lower is better):

```text
score = max(driverEta, passengerEta)
      + passengerBurdenWeight * passengerEta
      + modePenalty
```

Recommend switching away from stay-put only if the best alternative improves on the stay-put baseline by **≥ minImprovementMinutes** (default **1.5**). Otherwise recommend stay-put.

Constants live in one config object; do not scatter magic numbers.

---

## AI / LLM integration rules

Read `docs/AI_AGENT.md` before changing agent behavior.

### Modes

| Mode | When |
| --- | --- |
| A User key | Settings has baseUrl+apiKey+model; app calls vendor |
| B Proxy | Settings points at `server/`; server holds vendor key |
| C Offline | No LLM; engine + templates |

### Tool-loop limits

- Max tool iterations per user turn: **6** (configurable, keep small for mobile latency).
- On LLM failure mid-loop: finish with engine-only ranking + template copy.
- Persist a **tool trace** for the session turn (for debug UI / judges).

### Grounding checklist (must pass in review)

- [ ] UI minutes == tool fields  
- [ ] Selected meeting point ID ∈ tool candidates  
- [ ] If `dataSource=estimate`, badge visible  
- [ ] No free-text model coordinates used for map drawing  

---

## Implementation phases (do not skip prerequisites)

Follow `docs/IMPLEMENTATION_PLAN.md`. Summary:

| Phase | Goal | Exit criteria |
| --- | --- | --- |
| 0 | Scaffold + map spike + config | App launches; settings hold keys; map provider chosen |
| 1 | Deterministic engine + plan UI | Offline plan from two points; walk/bike/transit/stay cards |
| 2 | AI agent layer | Chat → tools → grounded plan; user key + offline |
| 3 | Session lock + share + polish constraints | Confirm locks plan; share/open maps; preference constraints |
| 4 | Contest polish | Fixtures, demo script, error states, docs sync |

**v1 explicitly excludes:** dual-phone sync, automatic mid-trip meeting-point updates, multi-agent negotiation.

When implementing a phase, update `docs/IMPLEMENTATION_PLAN.md` checkboxes / notes in the same PR when behavior lands.

---

## Coding conventions

### General

- TypeScript/ArkTS: explicit types on public APIs; prefer `readonly` data for plans.
- Pure functions for engine math; unit-test them without device.
- Names: `camelCase` for values, `PascalCase` for types/components, `UPPER_SNAKE` for constants only when true globals.
- Comments explain **why**, not restating the code.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

### UI

- ArkUI declarative components; keep screens thin; move logic to view-models / services.
- Always design empty / loading / error / offline states.
- zh-CN strings first; keep user-facing copy in a single l10n module when introduced.

### Domain engine

- Candidate generation, mode gating, scoring, ranking, stay-put decision are pure.
- Cap API fan-out (default max candidates = 4).
- Deterministic fallbacks when live routing is unavailable (straight-line + speed model is OK if labeled `estimate`).

### Server (optional)

- No business ranking duplication that can drift from `domain/` unless generated from shared code.
- Proxy should only auth + forward + rate-limit; not re-implement the engine unless explicitly designed later.

---

## Testing expectations

Before claiming a task done:

| Area | Expectation |
| --- | --- |
| Domain engine | Unit tests for spacing, reach, scoring monotonicity, stay-put threshold, per-mode reduction |
| Agent | Mock LLM + mock tools; assert grounding (no invented candidate IDs) |
| App | Smoke: settings, plan screen, confirm lock, share payload shape |
| Fixtures | At least one canned scenario produces stable recommended mode |

Do not mark Phase N complete without its exit criteria in `IMPLEMENTATION_PLAN.md`.

---

## Security & privacy

- Store keys in HarmonyOS secure preferences / app settings storage, not in code.
- Do not log full API keys.
- Minimize location retention; session data is in-memory unless user shares.
- Proxy must not write secrets into responses.

---

## Documentation duties

When you change behavior:

1. Update the relevant `docs/*` section if contracts change.
2. Keep `README.md` status/layout accurate.
3. Keep this `AGENTS.md` hard rules accurate if architecture shifts.
4. Prefer adding a short “Implementation note” under `docs/IMPLEMENTATION_PLAN.md` for non-obvious decisions.

---

## What “done” looks like for agents

A complete contribution:

1. Implements the requested slice **within phase scope**.
2. Preserves offline Mode C.
3. Does not invent dual-phone or auto mid-trip re-meeting.
4. Includes or updates tests for engine/agent changes.
5. Builds/lints as far as the current toolchain allows.
6. Leaves docs consistent.

---

## Quick command cheatsheet (fill in as toolchain lands)

```bash
# Domain tests (once test runner is wired)
# cd domain && npm test   # or project-equivalent

# Optional proxy
# cd server && <run per server/README.md>

# Harmony app: open in DevEco Studio and Run on device
```

If a command is missing, **add it to README + this section** when you wire it — do not leave tribal knowledge only in chat.

---

## Non-negotiable product constraints (v1)

- Single device plans the meeting.
- Meeting point chosen **once** at beginning (confirm = lock).
- AI is a **tool-using planner/explainer**, not a free-form navigator inventing roads.
- HarmonyOS phone HAP is the deliverable surface.
