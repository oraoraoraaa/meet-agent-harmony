# Manual checklist (v1)

Update as features land. Check before demo day.

## Launch

- [ ] App opens without keys
- [ ] Settings save/reload LLM + map fields
- [ ] Location permission denied still allows manual points

## Planning (offline)

- [ ] Load fixture scenario
- [ ] Plan returns stay-put + mode cards when reachable
- [ ] Data source badge shows 估算
- [ ] Selecting cards updates map preview

## Planning (live)

- [ ] Live route with map key
- [ ] Meeting name reverse-geocoded or coordinate fallback

## Agent

- [ ] Chat constraint changes options
- [ ] LLM failure falls back to engine
- [ ] Tool trace visible in debug sheet (if enabled)
- [ ] No secret values in trace

## Session

- [ ] Confirm locks plan
- [ ] Share text contains meeting + ETAs
- [ ] Open in Maps launches or web fallback
- [ ] Re-plan is explicit; does not silently mutate locked session

## Stability

- [ ] Airplane mode + fixtures still demos
- [ ] Kill/relaunch does not crash
