# Product: MeetAgent · 会合助手

## Vision

Help a driver and a passenger agree on a **fast, realistic meeting plan** under real traffic and multi-modal passenger movement — planned **once at the start of the trip**, explained clearly by an AI agent, and easy to act on (share / open maps).

## Problem

Fixed pickup points waste time:

- Traffic on the driver’s remaining path may make the original curb expensive.
- The passenger can often move a short distance (walk / bike / transit) to a better curb.
- People lack a joint view of **both** sides’ time costs.
- Black-box suggestions without explanation are hard to trust.

## Solution

MeetAgent on HarmonyOS:

1. Understands the pickup request (natural language + optional structured fields).
2. Uses map/routing tools + a local interception engine to produce options.
3. Uses an LLM agent to refine constraints and explain trade-offs **without inventing numbers**.
4. Lets the user confirm **one** plan, then share it or open navigation.

## Personas

### Driver planner (primary v1 user)

Runs the app before or at trip start. Inputs passenger location (search/map/GPS), optional self start, constraints. Chooses the meeting plan and shares it.

### Passenger (indirect v1 user)

Receives a shared plan (text/link). Does not need the app installed for v1.

## User stories (v1)

### US-1 Plan from two points

**As** a driver planner, **I want** to set my start and the passenger location **so that** I get ranked meeting options.

**Acceptance**

- Can set points via search, map tap, or current GPS.
- Produces stay-put + available mode suggestions.
- Shows ETAs and meeting point name/address when geocoding works.

### US-2 Natural language constraints

**As** a user, **I want** to say constraints in chat (“最多走8分钟，不坐公交”) **so that** ranking respects them.

**Acceptance**

- Intent parser fills structured constraints.
- Engine/agent filters or re-ranks accordingly.
- If LLM unavailable, structured toggles in UI still work.

### US-3 Explainable recommendation

**As** a user, **I want** a short reason for the top plan **so that** I can trust it.

**Acceptance**

- Reason cites grounded fields (minutes saved, mode, meeting name).
- Does not invent streets or times absent from tools.

### US-4 Confirm and lock

**As** a user, **I want** to confirm a plan **so that** it becomes the session plan.

**Acceptance**

- Confirm stores a locked `TripSession` with selected suggestion.
- UI shows locked state; no silent mutation of meeting point.
- Explicit “Re-plan” starts a new planning turn (manual).

### US-5 Share and navigate

**As** a user, **I want** to share the plan and open maps **so that** both sides can execute.

**Acceptance**

- Share copies human-readable summary + coordinates/link.
- Open in Maps launches a configured map app or web fallback.

### US-6 Offline / no-LLM

**As** a demo user without keys, **I want** a plan anyway **so that** the product remains usable.

**Acceptance**

- Engine returns estimate plans.
- UI badges `估算` / `Estimates only`.
- Chat may degrade to form-only planning.

## Non-functional targets (v1 aspirational)

| Metric | Target |
| --- | --- |
| Time to first plan (on-device, warm network) | ≤ 5 s typical; ≤ 8 s p95 with live routes |
| LLM tool loop | ≤ 6 tool calls / turn |
| Crash-free planning path | No uncaught fatal on missing keys |
| Language | zh-CN primary; EN secondary when time allows |

## Scope

### In scope (v1)

- Single HarmonyOS phone app
- One-shot planning + confirm lock
- Walk / bicycle / transit / stay-put options
- AI agent with tools + user key or proxy or offline
- Share text + open maps
- Fixture-based stage demo

### Out of scope (v1)

- Dual-phone realtime sync
- Automatic mid-trip meeting-point changes
- Ride payment / dispatch marketplace
- Full voice assistant OS integration (optional later)
- Multi-stop carpooling

## Success for contest demo

Judge can, in ~3 minutes:

1. Launch app on HarmonyOS phone.
2. Enter or load a pickup scenario.
3. See agent/tool-assisted multi-option plan on a map.
4. Understand why the top option wins.
5. Confirm, share, and open maps.
6. (Optional) Turn off LLM and still get a plan.
