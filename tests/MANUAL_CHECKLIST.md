# Manual checklist (v1)

Update as features land. Check before demo day.

## Launch

- [x] App opens without keys (Phase 0 shell / home)
- [x] Settings save/reload LLM + map fields (preferences store)
- [x] Location permission denied still allows app use (manual points later)

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
- [x] Kill/relaunch does not crash (shell)
- [x] Home shows settings summary after save
