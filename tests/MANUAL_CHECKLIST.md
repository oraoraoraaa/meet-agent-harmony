# Semifinal visual and functional checklist

- [x] SDK build for app and native test HAP.
- [x] Domain engine/grounding/session suite.
- [x] Map lifecycle tests and generated JavaScript syntax validation.
- [x] Emulator map selections → live planning → confirm lock → assistant/settings tabs.
- [ ] Physical phone pass, including keyboard, larger font sizes and external navigation app handoff.

Visual review: empty home, map search and assignment, preference form, result cards,
meeting-point panel, locked trip, assistant and settings. Estimate badges must remain visible.
No fixture picker, debug trace, sample-trip fallback, language toggle or decorative stage copy.

The native suite uses current device settings and selects map points through the actual Web view.
It writes the app’s `filesDir` (`meetagent-*.png`) for visual inspection. Leave the map key blank
for offline checks; no production fixture toggle exists.
