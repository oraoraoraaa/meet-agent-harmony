# MeetAgent · 会合助手

> 📌 月度激励申报材料：[`申报材料.md`](./申报材料.md)

**HarmonyOS AI agent for smarter pickup coordination.**

When a driver is on the way to pick someone up, the first chosen meeting point is often not the best one. Traffic changes, the passenger can walk / bike / take transit a short distance, and both people waste time by sticking to a fixed curb.

**MeetAgent** is a HarmonyOS phone app that plans a better meeting strategy **once at the start of the trip**, then hands both sides a clear, explainable plan.

It combines:

1. a **deterministic route-interception engine** (travel times, candidates, ranking), and  
2. an **LLM agent** (understand natural language, call tools, explain trade-offs, refine constraints).

> Dual-phone live sync and mid-trip meeting-point changes are **out of scope for v1**.  
> The driver (or whoever runs the app) locks a meeting plan at the beginning; that plan stays fixed unless the user manually re-runs planning.

---

## Product in one flow

```text
User describes the pickup
        │
        ▼
Agent parses intent + constraints
        │
        ▼
Tools: route · candidates · modes · POI · regeo
        │
        ▼
Local engine scores options
        │
        ▼
Agent explains & ranks
        │
        ▼
User confirms one plan
        │
        ▼
Share text / open in maps
```

### What the user gets

- Natural-language request (“司机从高新过来，我在钟楼，我可以骑车，别走太远”)
- Structured multi-option cards: **walk / bicycle / transit / stay put**
- Map preview of driver route + passenger path
- Plain-language **why** the top option wins
- One-tap **Open in Maps** and **Share plan**
- Works with **your own LLM API key**, an optional **proxy server**, or **offline rule-only mode**

---

## Repository layout

DevEco Studio opens the **repository root** (not a nested `app/` folder).

```text
.
├── README.md                 # you are here
├── AGENTS.md                 # operating manual for AI coding agents
├── AppScope/                 # HarmonyOS app metadata (bundle id, icon, label)
├── entry/                    # Main HAP module (ArkTS UI, abilities, resources)
├── build-profile.json5       # SDK products / modules
├── oh-package.json5          # OHPM dependencies
├── hvigorfile.ts             # Hvigor build entry
├── docs/
│   ├── PRODUCT.md
│   ├── ARCHITECTURE.md
│   ├── AI_AGENT.md
│   ├── IMPLEMENTATION_PLAN.md
│   ├── ROADMAP.md
│   └── DEMO_SCRIPT.md
├── domain/                   # portable domain models + engine (TS first)
├── server/                   # optional proxy contract (not implemented)
├── resource/                 # submission PDF/LaTeX, screenshots, reference template
├── fixtures/                 # canned scenarios for offline / stage demos
└── tests/                    # cross-cutting test notes & shared cases
```

---

## Design principles

1. **Numbers come from tools, not from the LLM.**  
   ETAs, distances, and polylines are produced by map/routing/engine tools. The model only chooses among tool results and explains them.

2. **Local engine is the backbone.**  
   Without any LLM key, the app still returns ranked plans (template explanations + `estimate` badge).

3. **One-shot plan lock for v1.**  
   Plan once → confirm → navigate/share. No automatic mid-trip meeting-point mutation.

4. **Graceful degradation always.**  
   Missing map key, missing LLM key, or network failure must not white-screen the app.

5. **HarmonyOS-native UX.**  
   Built for phones running HarmonyOS with ArkUI. Prefer platform design language over cloning other mobile stacks.

6. **Secrets never in git.**  
   LLM keys, map keys, and proxy tokens stay in local settings / env files.

---

## Tech stack (target)

| Layer | Choice |
| --- | --- |
| Client OS | HarmonyOS (phone) |
| UI | ArkTS + ArkUI (Stage model) |
| Domain / engine | TypeScript-first portable core under `domain/` (mirrored or imported into the app as practical) |
| Maps & routing | `MapProvider` Hybrid: **estimate** always; **AMap Web REST** when Map Web Key is set; Map Kit optional later for basemap only |
| LLM | OpenAI-compatible HTTP API (DeepSeek / Qwen / OpenAI / custom gateway) |
| Optional server | Lightweight proxy (`server/`) to hold a demo key |
| Tests | Domain unit tests + app UI smoke + fixture replay |

---

## Quick start

### 1) Open in DevEco Studio

1. **File → Open** and select this repository root:
   - `/Users/rinalic/Local/Github/meet-agent-harmony`
2. Let DevEco sync OHPM deps (`oh_modules/`, gitignored) and recreate `local.properties` if needed.
3. Configure debug signing for your device/emulator.
4. Run the `entry` module on a HarmonyOS phone or emulator.

### 2) Client config (keys never in git)

1. Open the **设置** tab:
   - **Map Web Key** — 高德 Web 服务 Key（`restapi.amap.com`）
   - Console 启用：路径规划（驾车/步行/骑行/公共交通）、地理编码 regeo、搜索 place/text
   - LLM（可选）：Base URL + API Key + Model，或 Proxy，或 Offline
2. Save → re-open Plan / Chat so provider rebuilds.
3. Optional template: copy `.env.example` → local `.env` (gitignored) for your notes only; the app reads **preferences**, not `.env`.

### 3) Planning paths

| Path | How |
| --- | --- |
| **Offline** | No map key · select both points · 路线规划 · badge **估算** |
| **Live map** | Map Web Key · 地图选点 → 路线规划 · badge **实时** / **实时+估算** |
| **LLM agent** | Mode A/B keys · 智能助手规划 · tools still use Hybrid map |

### 4) Optional LLM proxy

Mode B can connect to an existing OpenAI-compatible proxy. This repository does **not** include a runnable server yet; [`server/README.md`](server/README.md) records its intended contract. Set **Proxy mode** to your separately deployed endpoint.

### 5) Domain tests

```bash
cd domain && npm test
```

Map host lifecycle regression checks (Node 22.13+; native rendering still needs DevEco/device):

```bash
node --test tests/map-lifecycle.test.mjs tests/production-reply.test.mjs tests/rail-provider.test.mjs tests/current-location.test.mjs
```

Unsigned SDK build on macOS with the default DevEco installation:

```bash
PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p product=default -p module=entry@default \
  -p buildMode=debug assembleHap --no-daemon
```

The local emulator accepts the unsigned HAP. Physical-device installation needs local signing
in DevEco; do not commit signing credentials. Native smoke commands:

```bash
# Start the existing local emulator (preserve its data; adjust name/imageRoot if needed).
/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator \
  -start 'Pura 90' -imageRoot "$HOME/Library/Huawei/Sdk" -bootmode coldboot

# Native suite (connected device/emulator; current map settings)
# Build the test HAP with the same Hvigor command, using -p module=entry@ohosTest.
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc install \
  entry/build/default/outputs/default/entry-default-unsigned.hap
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc install \
  entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc shell \
  aa test -b com.rinalic.meetAgentHarmony -m entry_test \
  -s unittest OpenHarmonyTestRunner -s timeout 120000 -w 125
```

The native smoke selects both locations on the map and creates a locked session using current map settings.
Leave the map key empty for network-free testing. Screenshots are written to the app’s `filesDir` (`meetagent-*.png`). Inspect the `Tests run` summary: the test
launcher can exit successfully even when a test fails.

---

## Configuration

| Setting | Purpose |
| --- | --- |
| Map Web Key | AMap REST: driving/walking/bike/transit + regeo + POI |
| LLM base URL | OpenAI-compatible endpoint |
| LLM API key | User-provided key (Mode A) |
| LLM model | e.g. `deepseek-chat`, `qwen-plus`, … |
| Proxy base URL | Optional contest/demo server (Mode B) |
| Prefer modes | Walk / bike / transit allow-list (plan form) |
| Max passenger walk minutes | Soft constraint for ranking |

### LLM modes

| Mode | Behavior |
| --- | --- |
| **A. User key** | App calls vendor API directly with user-supplied key |
| **B. Proxy** | App calls a separately deployed compatible proxy; bundled server pending |
| **C. Offline** | No LLM; local engine + template copy |

Mode C must always work.

---

## Documentation map

| Doc | Read when you need… |
| --- | --- |
| [`docs/PRODUCT.md`](docs/PRODUCT.md) | Scope, personas, acceptance criteria |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Modules, sequence diagrams, fallbacks |
| [`docs/AI_AGENT.md`](docs/AI_AGENT.md) | Tool schemas, prompts, anti-hallucination rules |
| [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) | **Detailed phased implementation plan** |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestones and explicit non-goals |
| [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md) | 3-minute stage path |
| [`ARKTS_HARMONYOS_PERFORMANCE_OPTIMIZATION_GUIDE.md`](ARKTS_HARMONYOS_PERFORMANCE_OPTIMIZATION_GUIDE.md) | Performance reference supplied for this project |
| [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md) | Applied optimizations, evidence, and device validation gaps |
| [`AGENTS.md`](AGENTS.md) | Rules for AI coding agents working in this repo |

---

## Current status

**Semifinal interface** — a light native UI, map-first pickup selection, and labeled 地图 / 助手 / 行程 / 设置 navigation. Production screens contain no demo fixtures, debug traces, unfinished language switches, or sample trips. Planning uses selected locations, filling unset endpoints from a permitted current-location fix, and structured preferences. A map Web Service key is required: missing-key screens show a setup warning and block planning. LLM configuration remains optional. The optional proxy server remains a documented external integration, not a bundled feature.

| Layer | Status |
| --- | --- |
| Domain engine | Multi-modal ranking + agent grounding + session + AMap polyline helpers (`cd domain && npm test` → 36 pass) |
| Pickup validation | Live shortlist is routed to each candidate; destinations snapped over 60 m away are rejected. Nearby entrance names are landmarks, while parking legality remains for on-site confirmation. |
| Home map | Interactive AMap JS (calm basemap, traffic enabled initially) · location-row search / map selection · current-location defaults |
| 路线规划 | Draft-first read-only points · traffic-colored driving / colored transit legs + ETA tags · inline passenger itinerary · lock/share |
| Agent | OpenAI-compatible client, tool registry, orchestrator, `ChatPage` + route map |
| Session lock / share | `TripSessionStore` + `LockedSessionPage` + clipboard + map deep links |
| Map stack | `AmapWebMapProvider` + Hybrid + `InteractiveMapView` / `AmapMapHtml` |

---

## License / course use

Private project unless otherwise stated by the owners. Do not commit secrets, large binaries, or vendor SDK license keys.

Public transport planning includes real subway/train-station meeting candidates. Select
“地铁优先” in planning preferences to favor verified rail routes that improve on waiting
in place; unavailable rail data falls back transparently to ordinary planning.
