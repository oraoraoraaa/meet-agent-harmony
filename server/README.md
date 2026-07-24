# Optional LLM proxy (`server/`)

Thin OpenAI-compatible forwarder for **Mode B** demos so the phone does not need a raw vendor key.

## Status

Scaffold placeholder. Implement when Phase 4 (or earlier if demo needs it) starts.

## Intended API

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness |
| POST | `/v1/chat/completions` | Forward to upstream OpenAI-compatible vendor |

## Env (never commit real values)

```bash
UPSTREAM_BASE_URL=https://api.deepseek.com
UPSTREAM_API_KEY=sk-...
UPSTREAM_MODEL=deepseek-chat
HOST=0.0.0.0
PORT=8787
```

See `.env.example` at repo root for a combined template.

## Rules

- No reimplementation of the meeting engine here.
- No persistence of user chat content unless explicitly required later.
- Rate-limit if exposed beyond localhost.
