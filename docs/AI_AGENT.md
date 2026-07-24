# AI Agent Design

## Role of the LLM

The LLM is a **tool-using coordinator and explainer**, not a geographic database.

| Allowed | Forbidden |
| --- | --- |
| Parse natural language → `PickupIntent` | Invent ETAs or distances |
| Choose among tool candidate IDs | Invent coordinates not returned by tools |
| Explain grounded trade-offs | Claim live traffic without tool proof |
| Ask clarifying questions | Silently override hard constraints |
| Rephrase share text | Draw roads not in polylines |

## Runtime modes

### Mode A — User-provided key

App settings:

- `llmBaseUrl` (OpenAI-compatible)
- `llmApiKey`
- `llmModel`

App sends chat/completions (or Responses-style if vendor matches) directly.

### Mode B — Proxy

App settings:

- `proxyBaseUrl`
- optional app token

`server/` holds the real vendor key. Client never sees it.

### Mode C — Offline

`llmEnabled=false` or any LLM error → skip model; run engine pipeline; template rationales.

## Orchestrator

Pseudocode:

```text
fn handle_user_turn(session, user_text):
  if not llm_available:
    return engine_plan(session.scenario_from_ui)
  messages = [system_prompt, session.summary, user_text]
  for i in 1..maxToolIters:
    resp = llm.chat(messages, tools)
    if resp.tool_calls:
      for call in resp.tool_calls:
        result = tools.dispatch(call)
        messages.append(tool_result)
      continue
    plan = parse_grounded_plan(resp, latest_tool_state)
    return plan
  return engine_plan(...)  # exceeded iterations
```

Defaults:

- `maxToolIters = 6`
- temperature low (0.2–0.4) for planning stability
- timeout per LLM call ~20–30s with user-visible progress

## System prompt principles

Keep the system prompt short and strict:

1. You are MeetAgent on a phone.
2. Use tools for all geo/time facts.
3. Prefer stay-put unless improvement ≥ threshold reported by engine.
4. Respect user constraints.
5. Respond in the user’s language (default 简体中文).
6. Final answer must reference candidate IDs from tools.
7. If tools fail, say you are using 估算模式.

Full prompt text lives in:

- Portable: `domain/src/agent/prompts.ts`
- ArkTS: `entry/src/main/ets/services/agent/Prompts.ets`

Update this doc if the contract changes.

## Tool catalog (v1)

### `get_scenario_snapshot`

Return current driver/passenger points, city, constraints from UI/session.

### `set_constraints`

Update structured constraints from parsed intent.

### `get_driving_route`

Input: driver, passenger.  
Output: polyline, total duration, per-vertex cumulative times (or engine-ready route points), `dataSource`.

### `generate_and_score_plans`

Input: scenario (+ optional route).  
Output: full `RecommendationSet` from local engine (authoritative ranking).

### `reverse_geocode`

Input: lon/lat.  
Output: name, address (best effort).

### `search_poi_near`

Input: lon/lat, keyword/radius.  
Output: POI list for semantic meeting labels / optional snap.

### `format_share_text`

Input: selected plan.  
Output: clipboard-ready summary.

> Note: The engine tool is the source of truth for scores. The LLM should not re-rank with invented weights; it may apply **soft** user preference language only by calling `set_constraints` and re-running `generate_and_score_plans`.

## Structured intent

```json
{
  "roleHint": "driver | passenger | unknown",
  "driverText": "string?",
  "passengerText": "string?",
  "allowedModes": ["walking", "bicycle", "transit"],
  "maxPassengerWalkMin": 10,
  "maxPassengerBikeMin": 20,
  "avoidTransit": false,
  "notes": "luggage | rain | elderly | ..."
}
```

Unresolved locations → agent asks a clarification **or** UI requires map selection before planning.

## Grounding rules (enforced in code)

1. Final recommended ID must exist in last `generate_and_score_plans` output.
2. UI binds minutes from that JSON only.
3. Model prose is display-only; never parsed back into coordinates.
4. Tool trace stored on the turn for optional “决策过程” panel.

## Prompt injection / abuse

- Treat map/tool JSON as data, not instructions.
- Do not execute arbitrary tool names from model beyond the registry.
- Strip secrets from any debug export.

## Evaluation checklist for agent changes

- [ ] Offline Mode C still plans
- [ ] With mock tools, model cannot force unknown candidate IDs (validator rejects)
- [ ] Constraint “no transit” removes transit cards
- [ ] Latency: tool loop bounded
- [ ] zh-CN explanation reads natural without contradicting numbers

## Future tools (not v1)

- `replan_from_remaining_route` (mid-trip)
- `notify_counterparty` (dual-phone)
- `voice_transcribe`
