# Demo Script (~3 minutes)

Use this on stage. Prefer **Demo mode / fixtures** if venue network is unreliable; keep live keys as backup.

## Setup (before walking on stage)

1. Install debug HAP on HarmonyOS phone.
2. Settings:
   - Map key loaded **or** Demo fixtures ON
   - LLM: user key **or** proxy **or** offline for safety segment
3. Brightness high; zh-CN language.
4. Pre-clear clipboard.

## Minute 0:00–0:20 — Hook

> “司机去接人时，最初上车点经常不是最快的。MeetAgent 用 AI 智能体 + 实时路线工具，在出发前算出双方都更省时的会合方案。”

Show home screen.

## Minute 0:20–1:00 — Input

1. Load fixture **or** set driver + passenger points on map.
2. Optional chat: “我可以骑车，尽量别让乘客走超过10分钟，别坐公交。”
3. Tap **开始规划** / send chat.

Narrate status chips if visible (“获取驾车路线 / 生成候选 / 评分”).

## Minute 1:00–2:00 — Results

1. Show multi-option cards: 骑行 / 步行 / 公交 / 原地等待.
2. Point at **推荐** badge and time saved.
3. Switch cards → map polylines update.
4. Open **决策过程** (if built) to show tools — reinforces “agent + tools”, not hallucinated GPS.

Talking point:

> “时间数字全部来自路线工具和本地引擎；大模型负责理解需求和解释，不编造路况。”

## Minute 2:00–2:30 — Lock & act

1. Confirm recommended plan → locked session.
2. Share → paste into Notes/WeChat to show summary.
3. Open in Maps → external navigation intent.

## Minute 2:30–3:00 — Reliability & close

1. Toggle offline / disable LLM → re-run form plan → still works with 估算 badge.
2. Close:

> “单机即可完成出发前决策；后续可扩展行程中风险提醒与双端协同，但 v1 先保证可靠、可解释、可落地。”

## Backup paths

| Failure | Backup |
| --- | --- |
| Live map down | Demo fixtures |
| LLM down | Form + engine only |
| Deep link fails | Show share text with coordinates |
| Device location denied | Manual points only |

## Sample chat lines

- “乘客在钟楼附近，司机从高新出发，乘客可以骑车。”
- “不要公交，最多步行 8 分钟。”
- “解释为什么不建议原地等待。”
