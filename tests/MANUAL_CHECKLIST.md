# Manual checklist (v1)

Update as features land. Check before demo day.

## Launch

- [x] App opens without keys (Phase 0 shell / home)
- [x] Settings save/reload LLM + map fields (preferences store)
- [x] Location permission denied still allows app use (manual points later)

## Planning (offline / demo fixtures)

- [x] Load fixture scenario (西安 / 上海)
- [x] Plan returns stay-put + mode cards when reachable
- [x] Data source badge shows 估算
- [x] Selecting cards updates map preview
- [x] Settings **演示 Fixture 优先 ON** forces estimate even if Map Web Key present
- [x] Domain unit tests green (`cd domain && npm test` — 25 pass incl. polyline helpers)

## Planning (live AMap)

- [x] Settings: paste Map Web Key, turn **演示 Fixture 优先 OFF**, Save
- [x] Home interactive map + traffic; search/tap assign passenger/driver
- [x] Plan with draft points → badge **实时** or **实时+估算** (not pure 估算 when network OK)
- [x] ETAs / polylines differ from pure straight-line estimate for same points
- [x] Loading copy shows 「正在获取驾车路线…」
- [x] Live failure (bad key / airplane) degrades without crash → 实时+估算 or 估算
- [x] Meeting place reverse-geocoded to POI/address (no bare coords primary UI)
- [x] Result map paints on first entry; card select updates routes
- [x] Chat plan response includes interactive map + card→route

## Agent

- [ ] Chat constraint changes options (Mode A/B with key — device)
- [x] Offline chat path plans without LLM (Mode C)
- [x] LLM failure falls back to engine (orchestrator code path)
- [x] Tool trace visible via ChatPage「轨迹」
- [x] No secret values in trace (only tool names / timings / summaries)
- [ ] Settings「测试 LLM 连接」succeeds with real key
- [x] Chat uses same Hybrid provider (demoFixtures + mapWebKey)
- [x] Chat intro shows current driver/passenger place labels from draft

## Session

- [x] Confirm locks plan (code path; verify on device)
- [x] Share text contains meeting + ETAs + dataSource label
- [x] Open in Maps launches or web fallback
- [x] Re-plan is explicit; does not silently mutate locked session
- [ ] Locked session freezes **live** snapshot the same as estimate (device)

## Stability

- [x] Airplane mode + demo fixtures still demos
- [x] Kill/relaunch does not crash (shell)
- [x] Home shows settings summary after save (includes AMap / Fixture status)
- [ ] No keys in `git status` / committed files

## AMap console checklist

Enable on Web service key:

- [ ] 路径规划 · driving
- [ ] 路径规划 · walking
- [ ] 路径规划 · bicycling
- [ ] 路径规划 · transit/integrated
- [ ] 地理编码 · regeo
- [ ] 搜索 · place/text
