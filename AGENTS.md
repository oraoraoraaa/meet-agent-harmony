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

1. **HarmonyOS client is the product surface.** Primary UI is ArkTS/ArkUI under `entry/` (DevEco project at **repo root**). Do not introduce Flutter/React Native/Android-Java UI as the main app.
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
11. **Git: local commits OK; push only after human confirmation.** See [Git workflow](#git-workflow) below. Never `git push` mid-debug or “just to share.”
12. **Verify before claiming done.** Prefer DevEco Preview/device run for UI and ArkTS compile errors; ad-hoc scripts are not a substitute for a green Preview when platform APIs are involved.
13. **Keep commit history clean.** If a local commit is later found broken (Preview/build/runtime fail), **do not stack fix commits on a known-bad tip as the permanent story** — undo that local commit (prefer `git reset --soft HEAD~1` while unpushed, or equivalent) and recommit a corrected single logical change. Do not rewrite history that is already on `origin` without explicit human approval.

---

## Git workflow

This project keeps **`origin` history clean**. Agents must follow:

### When to commit (local)

- After a coherent feature or fix slice is implemented (Conventional Commits: `feat:`, `fix:`, `docs:`, …).
- Prefer **one logical change per commit** over giant mixed dumps.
- Local commits are encouraged so work is checkpointed on the machine.

### When **not** to push

- **Do not `git push`** (or otherwise publish to `origin`) until the **human explicitly confirms**.
- Confirmation implies: features under test look good, DevEco Preview/Run (or agreed checks) passed, and history is acceptable.
- “It compiles on my ad-hoc script” is **not** permission to push.

### If a local commit turns out broken

1. Stop. Do **not** push the bad commit.
2. Fix the code.
3. **Rewrite the local tip** so the broken commit is not left as permanent history:
   - Preferred while unpushed: `git reset --soft HEAD~1` (keeps changes staged) → fix → `git commit` again with an accurate message.
   - Or amend only if the bad commit was the latest, unpushed, and the human is fine with amend for that tip.
4. Re-verify (DevEco Preview/Run when ArkTS/UI is involved).
5. Only after human confirmation → push.

### If history is already on remote

- Do **not** force-push or rewrite shared history unless the human explicitly asks.
- Use a normal follow-up `fix:` commit instead.

### Pre-push checklist (agents)

- [ ] Feature works in DevEco Preview and/or device run (as applicable)
- [ ] No secrets in the tree
- [ ] Docs/`AGENTS.md` updated if contracts changed
- [ ] Local history is intentional (no known-broken tip commits)
- [ ] Human said to push

---

## Repository map

The HarmonyOS / DevEco project is the **repository root** (open this folder in DevEco Studio).

```text
AppScope/   App-level bundle metadata, icons, label
entry/      Main HAP module — ArkTS UI, abilities, resources, features/services
domain/     Portable models + interception engine + pure ranking logic
server/     Optional demo LLM proxy (not required for offline Mode C)
fixtures/   Canned scenarios & golden tool outputs for demos/tests
docs/       Product, architecture, AI, implementation plan, roadmap, demo script
tests/      Shared test notes / cross-layer cases
```

### Where to put new code

| Change type | Put it in |
| --- | --- |
| UI screens, navigation, Harmony permissions | `entry/src/main/ets/` |
| Geo types, scoring, candidate gen, plan models | `domain/` |
| LLM HTTP client, tool loop, prompts | `entry/.../services/agent|llm/` and/or pure helpers under `domain/` |
| Map vendor SDK wrappers | `entry/.../services/map/` behind a provider interface |
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
5. Builds/lints as far as the current toolchain allows (DevEco Preview/Run for ArkTS UI).
6. Leaves docs consistent.
7. **Does not `git push` unless the human explicitly confirmed** after verifying the feature works.
8. If a local commit was bad, **reverted/recommitted cleanly** (see [Git workflow](#git-workflow)) rather than leaving a broken tip in history.

---

## Quick command cheatsheet (fill in as toolchain lands)

```bash
# Domain unit tests
cd domain && node --experimental-strip-types --test test/**/*.test.ts

# Optional proxy
# cd server && <run per server/README.md>

# Harmony app: DevEco Studio → Open repository root → Run entry
# /Users/rinalic/Local/Github/meet-agent-harmony

# Git: commit locally when a slice is ready; PUSH ONLY after human confirmation
# git add … && git commit -m "feat: …"
# git push   # ← only when the human says so
```

If a command is missing, **add it to README + this section** when you wire it — do not leave tribal knowledge only in chat.

---

## Non-negotiable product constraints (v1)

- Single device plans the meeting.
- Meeting point chosen **once** at beginning (confirm = lock).
- AI is a **tool-using planner/explainer**, not a free-form navigator inventing roads.
- HarmonyOS phone HAP is the deliverable surface.
