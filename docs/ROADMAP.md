# Roadmap

## v1 — Contest MVP (current)

**Codename:** Plan B · Session AI Agent (single-device, one-shot lock)

- Deterministic multi-modal meeting planner
- LLM tool-using agent (user key / proxy / offline)
- Confirm → lock meeting plan
- Share + open maps
- Fixtures for stage safety

See `IMPLEMENTATION_PLAN.md`.

## v1.1 — Practical hardening

- Better semantic meeting points (POI quality filters)
- Richer transit step display
- Stronger preference memory
- Improved deep links for more map apps
- Telemetry opt-in for demo metrics (local only)

## v2 — Active trip assistance (optional)

> Only after v1 done. Requires explicit scope unlock.

- Monitor driver progress along locked route (ETA refresh)
- Alert if **arrival risk** changes — still **does not auto-change meeting point** unless user accepts a new plan
- Voice input for hands-free constraint updates before lock

## v3 — Multi-party (optional)

- Dual-phone session room
- Passenger accept/reject
- Lightweight negotiation messages

## Explicit non-goals (until reopened)

- Ride payment
- Driver marketplace dispatch
- Full autonomy without user confirm
- Replacing professional navigation SDKs

## Priority rule

If schedule slips: **preserve Phase 1 + Mode C + confirm/share**, then AI chat, then polish. Never ship AI without grounded engine numbers.
