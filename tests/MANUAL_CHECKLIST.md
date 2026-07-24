# Manual checklist (v1)

Update as features land. Check before demo day.

## Launch

- [x] App opens without keys (Phase 0 shell / home)
- [x] Settings save/reload LLM + map fields (preferences store)
- [x] Location permission denied still allows app use (manual points later)

## Planning (offline)

- [x] Load fixture scenario
- [x] Plan returns stay-put + mode cards when reachable
- [x] Data source badge shows 估算
- [x] Selecting cards updates map preview

## Planning (live)

- [ ] Live route with map key
- [ ] Meeting name reverse-geocoded or coordinate fallback

## Agent

- [ ] Chat constraint changes options (Mode A/B with key — device)
- [x] Offline chat path plans without LLM (Mode C)
- [x] LLM failure falls back to engine (orchestrator code path)
- [x] Tool trace visible via ChatPage「轨迹」
- [x] No secret values in trace (only tool names / timings / summaries)
- [ ] Settings「测试 LLM 连接」succeeds with real key
## Session

- [ ] Confirm locks plan
- [ ] Share text contains meeting + ETAs
- [ ] Open in Maps launches or web fallback
- [ ] Re-plan is explicit; does not silently mutate locked session

## Stability

- [ ] Airplane mode + fixtures still demos
- [x] Kill/relaunch does not crash (shell)
- [x] Home shows settings summary after save
