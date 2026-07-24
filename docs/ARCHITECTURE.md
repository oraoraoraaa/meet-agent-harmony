# Architecture

## Overview

MeetAgent is a **client-centric** HarmonyOS app with an optional demo proxy.

```text
┌─────────────────────────────────────────────────────────┐
│           HarmonyOS App (repo root / entry module)      │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │ ArkUI      │  │ Session VM  │  │ Settings store   │  │
│  │ Chat/Map/  │◄─┤ Plan lock   │  │ keys · prefs     │  │
│  │ Plan/Share │  └──────┬──────┘  └────────┬─────────┘  │
│  └─────▲──────┘         │                  │            │
│        │         ┌──────▼──────────────────▼─────────┐  │
│        │         │     Agent Orchestrator            │  │
│        │         │  memory · tool loop · formatter   │  │
│        │         └──────┬───────────────┬────────────┘  │
│        │                │               │               │
│  ┌─────┴──────┐  ┌──────▼──────┐ ┌──────▼───────────┐  │
│  │ LLM client │  │ Tool host   │ │ Local engine     │  │
│  │ A/B/C mode │  │ map·poi·…   │ │ domain/          │  │
│  └─────▲──────┘  └──────▲──────┘ └──────────────────┘  │
└────────┼────────────────┼───────────────────────────────┘
         │                │
         │         ┌──────▼──────┐
         │         │ Map / Route │  vendor SDK or HTTP
         │         │ Provider    │
         │         └─────────────┘
         │
  ┌──────▼──────────────┐
  │ Optional server/    │  LLM proxy only (Mode B)
  └─────────────────────┘
```

## Modules

### Repo-root HarmonyOS project (`AppScope/` + `entry/`)

DevEco opens the **git repository root**. The main HAP module is `entry/`.

Responsibilities:

- UI screens and navigation
- Permissions (location, network, queries for map schemes)
- Platform map view
- Secure settings storage
- Agent orchestration wiring
- Share sheet / deep links

Suggested feature folders (create as implementation proceeds):

```text
entry/src/main/ets/
  pages/
  features/
    home/
    chat/
    map_plan/
    session/
    settings/
  services/
    agent/
    llm/
    map/
    location/
    share/
  common/
```

### `domain/` — pure planning core

Responsibilities:

- Geo / scenario / suggestion types
- Route-interception candidate generation
- Mode gating, scoring, ranking, stay-put decision
- Per-mode reduction (`bestPerMode`)
- Engine config defaults

Must remain testable without DevEco.

### `server/` — optional proxy

Responsibilities:

- Hold vendor LLM key for stage demos
- Forward OpenAI-compatible chat/completions
- Optional light rate limit

Must not be required for Mode C.

### `fixtures/`

- Scenario JSON (driver/passenger points, city)
- Optional recorded route polylines for offline demos

## Core data contracts

### Scenario (input)

```json
{
  "driver": { "name": "Driver", "lon": 108.94, "lat": 34.34 },
  "passenger": { "name": "Passenger", "lon": 108.95, "lat": 34.26 },
  "city": "西安",
  "constraints": {
    "allowedModes": ["walking", "bicycle", "transit"],
    "maxPassengerWalkMin": 10,
    "avoidTransit": false
  }
}
```

### RecommendationSet (output)

```json
{
  "generatedAt": "ISO-8601",
  "dataSource": "live | live_with_fallback | estimate",
  "stayPut": {
    "recommended": false,
    "driverEtaMin": 28,
    "completionMin": 28,
    "meetingPoint": { "lon": 108.95, "lat": 34.26, "name": "…" },
    "driverRoutePolyline": []
  },
  "suggestions": [
    {
      "mode": "bicycle",
      "recommended": true,
      "meetingPoint": { "lon": 108.93, "lat": 34.28, "name": "…" },
      "driverEtaMin": 14,
      "passengerEtaMin": 16,
      "completionMin": 16,
      "driverSavedMin": 14,
      "score": 16.4,
      "rationale": "grounded text",
      "driverRoutePolyline": [],
      "passengerPathPolyline": []
    }
  ]
}
```

Exactly one of `stayPut.recommended` or a `suggestions[i].recommended` is true.

### TripSession (v1)

```json
{
  "id": "uuid",
  "status": "planning | confirmed | closed",
  "scenario": {},
  "recommendationSet": {},
  "selected": { "kind": "suggestion|stayPut", "index": 0 },
  "lockedAt": "ISO-8601"
}
```

Once `status=confirmed`, meeting point fields are immutable unless user starts a new plan.

## Planning algorithm (engine)

1. Build driver route to passenger (live or estimate).
2. Attach cumulative driver time along polyline vertices.
3. Generate candidates on route within passenger reach; enforce min move, min driver saving, spacing, max count.
4. For each candidate × reachable mode, estimate passenger ETA.
5. Score, rank, reduce to best per mode.
6. Apply stay-put threshold (`minImprovementMinutes`).
7. Attach polylines for UI.

Semantic POI enrichment (prefer named curb near candidate) is a Phase 3 enhancement layered on top — never block core scoring if POI fails.

## Agent loop

```text
user message
  → orchestrator builds messages + tool defs
  → LLM may call tools (bounded)
  → tools hit map provider / domain engine
  → LLM returns final structured choice + explanation
  → UI renders RecommendationSet + narrative
```

If LLM disabled: UI calls engine tools directly.

## Fallback matrix

| Failure | Behavior |
| --- | --- |
| No map key | Estimate routes; schematic map if needed |
| Route API fail | Straight-line fallback route |
| Passenger mode API fail | Speed-model ETA for that mode |
| No LLM | Form + engine + templates |
| LLM timeout | Engine result + warning toast |
| POI/regeo fail | Show coordinates + generic label |

## Security

- Keys in secure local storage
- Proxy strips vendor key from client
- No secret logging
- HTTPS only for LLM/map HTTP

## Extensibility hooks (post-v1)

Interfaces should allow later:

- Mid-trip re-evaluation (explicit opt-in)
- Dual-end session room
- Alternate map vendors

…without rewriting domain scoring.
