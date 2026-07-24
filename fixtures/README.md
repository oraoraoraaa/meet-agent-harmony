# Fixtures

Canned scenarios and optional recorded tool outputs for:

- offline demos
- unit/integration tests
- stage reliability

## Layout

```text
fixtures/
  scenarios/     # driver + passenger + city + constraints
  routes/        # optional recorded polylines (later)
  README.md
```

## Rules

- No API keys.
- Prefer GCJ-02 coordinates consistent with China map providers.
- Keep scenarios realistic but anonymized.
