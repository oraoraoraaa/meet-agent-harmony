# Semifinal visual and functional checklist

- [x] SDK build for app and native test HAP.
- [x] Domain engine/grounding/session suite.
- [x] Map lifecycle tests and generated JavaScript syntax validation.
- [x] Emulator map selections → live planning → confirm lock → assistant/settings tabs.
- [x] 公共交通 label and 地铁优先 selection render correctly; live station entrance is offered.
- [x] Rail preference, station eligibility, API parsing and unavailable-data fallback tests.
- [x] Native endpoint search, populated passenger itinerary, and missing-key warning/blocking.
- [x] Native location permission and unavailable-fix guidance; successful fix semantics covered by host tests.
- [ ] Physical phone pass, including keyboard, larger font sizes and external navigation app handoff.

Visual review: empty home, map search and assignment, preference form, result cards,
meeting-point panel, locked trip, assistant and settings. Estimate badges must remain visible.
No fixture picker, debug trace, sample-trip fallback, language toggle or decorative stage copy.

The native suite uses current device settings and selects map points through the actual Web view.
It writes the app’s `filesDir` (`meetagent-*.png`) for visual inspection. Clear the map key to check the setup warning and blocked planning; restore it afterward.
No production fixture toggle exists.

Location and itinerary checks:

- Tap either endpoint row, search for a station and select it; verify the other endpoint is preserved.
- Plan with one or both endpoints unset; grant location and verify only unset endpoints use the fix.
- Deny location or disable positioning; verify useful guidance and manual selection remain available.
- Verify traffic is initially active and there is no map search bar.
- Tap 公共交通 on results; scroll below the cards to inspect walking, boarding/alighting and transfer details. No popup, close button or forced scroll should occur.
- When routing fails after map setup, verify the timeline explicitly reports unavailable detailed routing.

- Check driving traffic colors against returned TMC status; unknown sections stay blue.
- Check two distinct transit lines use separate colors and walking stays dashed.
- Check route ETA tags match the selected card and persist on the locked-trip map.
