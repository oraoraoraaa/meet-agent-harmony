# MeetAgent · 会合助手

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
├── server/                   # optional LLM proxy for demos
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
| Maps & routing | `MapProvider` Hybrid: **estimate** always; **AMap Web REST** when Map Web Key set and 演示 Fixture OFF; Map Kit optional later for basemap only |
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

> Do **not** keep developing only under `~/DevecostudioProjects/meet_agent_harmony` — that folder was the generator seed. The GitHub path is the source of truth.

### 2) Client config (keys never in git)

1. In-app **设置**:
   - **Map Web Key** — 高德 Web 服务 Key（`restapi.amap.com`）
   - Console 启用：路径规划（驾车/步行/骑行/公交）、地理编码 regeo、搜索 place/text
   - **演示 Fixture 优先** — ON = 强制估算（舞台稳）；OFF + Key = 实时路线
   - LLM（可选）：Base URL + API Key + Model，或 Proxy，或 Offline
2. Save → re-open Plan / Chat so provider rebuilds.
3. Optional template: copy `.env.example` → local `.env` (gitignored) for your notes only; the app reads **preferences**, not `.env`.

### 3) Three demo paths

| Path | How |
| --- | --- |
| **Offline / Fixture** | 演示 Fixture ON · 普通规划 · 主页选点或示例回退 · badge **估算** |
| **Live map** | Fixture OFF · Map Web Key · 主页地图选点 → 普通规划 · badge **实时** / **实时+估算** |
| **LLM agent** | Mode A/B keys · 智能助手规划 · tools still use Hybrid map |

### 4) Optional LLM proxy

```bash
cd server
# follow server/README.md after scaffold
```

Point Settings → **Proxy mode** at that base URL for stage demos without pasting a vendor LLM key on the device.

### 5) Domain tests

```bash
cd domain && npm test
```

---

## Configuration

| Setting | Purpose |
| --- | --- |
| Map Web Key | AMap REST: driving/walking/bike/transit + regeo + POI |
| Map API Key | Optional SDK slot (not required for Hybrid REST) |
| 演示 Fixture 优先 | Force estimate provider (ignore Map Web Key) |
| LLM base URL | OpenAI-compatible endpoint |
| LLM API key | User-provided key (Mode A) |
| LLM model | e.g. `deepseek-chat`, `qwen-plus`, … |
| Proxy base URL | Optional contest/demo server (Mode B) |
| Prefer modes | Walk / bike / transit allow-list (plan form) |
| Max passenger walk minutes | Soft constraint for ranking |
| Language | zh-CN (default); EN/JP deferred |

### LLM modes

| Mode | Behavior |
| --- | --- |
| **A. User key** | App calls vendor API directly with user-supplied key |
| **B. Proxy** | App calls your `server/` which holds the real key |
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
| [`AGENTS.md`](AGENTS.md) | Rules for AI coding agents working in this repo |

---

## Current status

**Phase 4 largely landed** — live AMap Hybrid (REST + JS basemap), home search-first assign, plan/chat route maps, demo polish. Remaining: page transitions, icons/about, optional `server/` proxy, JP l10n.

| Layer | Status |
| --- | --- |
| Domain engine | Multi-modal ranking + agent grounding + session + AMap polyline helpers (`cd domain && npm test` → 25 pass) |
| Home map | Interactive AMap JS (traffic) · search/tap → assign passenger/driver · POI labels |
| 普通规划 | Draft-first read-only points · result map + card routes · lock/share |
| Agent | OpenAI-compatible client, tool registry, orchestrator, `ChatPage` + route map |
| Session lock / share | `TripSessionStore` + `LockedSessionPage` + clipboard + map deep links |
| Map stack | `AmapWebMapProvider` + Hybrid + `InteractiveMapView` / `AmapMapHtml` |

---

## License / course use

Private project unless otherwise stated by the owners. Do not commit secrets, large binaries, or vendor SDK license keys.
