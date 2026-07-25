# Demo Script (~3 minutes)

Use this on stage. Prefer **演示 Fixture 优先 ON** if venue network is unreliable; keep live AMap keys as backup.

## Setup (before walking on stage)

1. Install debug HAP on HarmonyOS phone / emulator.
2. Settings:
   - **演示 Fixture 优先**: ON for safe path; OFF + Map Web Key for live path
   - Map Web Key: AMap Web service key (never commit)
   - LLM: offline **or** user key / proxy
3. Brightness high; zh-CN language.
4. Pre-clear clipboard.

## Minute 0:00–0:20 — Hook

> “司机去接人时，最初上车点经常不是最快的。MeetAgent 用 AI 智能体 + 路线工具，在出发前算出双方都更省时的会合方案。”

Show home screen (map stage + bottom sheet). Point at header **司机模式 / 乘客模式** chip if relevant.

## Minute 0:20–1:00 — Input

### Safe path (default)

1. Home map: search or tap a place → assign **乘客 / 司机** (mode-aware sheet).
2. Tap **普通规划** (read-only draft points).
3. Optional: toggle 步行 / 骑行 / 公交 · 避免公交 · 最长步行.
4. Tap **开始路线优化**.

### Live path (optional segment)

1. Settings → 演示 Fixture **OFF** → paste Map Web Key → 保存.
2. Home: real basemap + 路况; pick points → **普通规划** → badge **实时** / **实时+估算**.
3. Switch result cards → map polylines update.

### Chat path

1. Home → **智能助手规划** (intro shows driver/passenger place names).
2. Quick prompt or: “我可以骑车，尽量别让乘客走超过10分钟，别坐公交。”
3. Send; show plan cards **and** interactive route map.

## Minute 1:00–2:00 — Results

1. Multi-option cards: 骑行 / 步行 / 公交 / 原地等待.
2. Point at **最快方案** badge and time saved.
3. Switch cards → **interactive map** routes update (engine geometry).
4. 会合地点 shows **POI/address**, not bare coordinates.
5. Open **决策过程** / 轨迹 if chat path — tools only, no secrets.

Talking point:

> “时间数字全部来自路线工具和本地引擎；大模型负责理解需求和解释，不编造路况。”

## Minute 2:00–2:30 — Lock & act

1. **确认并锁定方案** → Locked session.
2. **复制分享** → paste into Notes/WeChat (device clipboard; Preview may not bridge Mac).
3. **在地图中打开** → system map / web fallback.

## Minute 2:30–3:00 — Reliability & close

1. Settings → 演示 Fixture ON (or airplane) → re-run 普通规划 → still works with **估算**.
2. Close:

> “单机即可完成出发前决策；后续可扩展行程中风险提醒与双端协同，但 v1 先保证可靠、可解释、可落地。”

## Backup paths

| Failure | Backup |
| --- | --- |
| Live map down | 演示 Fixture 优先 ON |
| LLM down | Form + engine only (Mode C) |
| Deep link fails | Share text with coordinates |
| Device location denied | Fixtures / manual coords |
| POI empty | Map tap + regeo label / hand-adjust on home |

## Sample chat lines

- “乘客在钟楼附近，司机从高新出发，乘客可以骑车。”
- “不要公交，最多步行 8 分钟。”
- “解释为什么不建议原地等待。”
