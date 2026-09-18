# Performance audit — 2026-09-15, verified 2026-09-16

Reference: [ArkTS/HarmonyOS guide](../ARKTS_HARMONYOS_PERFORMANCE_OPTIMIZATION_GUIDE.md).
Target: HarmonyOS 6.1.1, API 24, ArkUI Stage application.

## Applied changes

The repeated work found in the map host is avoidable even before native profiling:

- Marker coordinates and the refresh token previously triggered separate full HTML loads.
  `InteractiveMapView` now queues one refresh per synchronous update batch, reads the final
  props, and skips identical HTML. A changed route or map configuration still refreshes.
- Removed the unconditional 100 ms reload after Web attachment and the 120 ms follow-up
  reload on result pages. Retained the existing 80 ms result-map mount deferral because
  the project records a zero-size first-paint issue; this delay is not a general tuning rule.
- Map attachment and timer handles are ordinary fields. Removed unused observed readiness
  state and the empty appearance hook. Queued refreshes/mounts are cancelled on destruction;
  delayed mount callbacks check disposal before touching state.
- Home reads settings on page show, rather than both appearance and page show. Labels,
  role selection, and unchanged settings no longer request map reloads.
- Removed `.key()` test tags that had been described as a production remount mechanism.
  Refresh behavior uses the explicit watched token.

The HTML cache retains only the current page and is cleared on destruction. It must never
be logged because live map HTML contains the configured key.

## Evidence and limits

A controlled Node harness executed the actual map host methods from baseline `6044e80`
and the changed source with a fake Web controller and deterministic timers:

| Same input sequence | Baseline | Updated |
| --- | --- | --- |
| Attach, change longitude, change latitude, bump token, flush queued work | 4 HTML loads | 1 HTML load |

This is a count of redundant host operations, **not** a measurement of native startup,
frame rate, CPU time, memory, or AMap network latency. It excludes the baseline's additional
100/120 ms retries. No device performance improvement percentage is claimed.

Verification commands:

```bash
cd domain && npm test
# From repository root, Node 22.13+:
node --test tests/map-lifecycle.test.mjs
```

- Portable domain: 25 passing tests covering engine, grounding, polyline helpers, and lock.
- Map host: four passing tests covering batched final snapshots, route refresh/deduplication,
  destruction/reattachment, and load failure fallback/retry.
- SDK: unsigned app and `entry@ohosTest` HAP builds pass. Generated string assertion examples
  were replaced by two meaningful ArkTS engine-port checks. Both also pass on the API-24
  Pura 90 emulator.
- DevEco Preview: home shell, offline planning form, estimate result cards, and card
  selection exercised; chat shell also renders. Web maps report
  “Preview not available for this component.”
- Native Pura 90 / API 24: app installs; the home AMap basemap renders with traffic and pins.
  The native smoke test navigates to planning, calculates a live plan, and confirms the lock.
  Captured plan/locked screens show driver and passenger polylines and matching tool ETAs.
  Basemap tiles can still be loading when the first result screenshot is captured.
- The initial emulator blocker was a stale SDK path, not a missing image. Launch succeeded
  with `Emulator -start 'Pura 90' -imageRoot /Users/rinalic/Library/Huawei/Sdk -bootmode coldboot`.
- Physical-device frame/CPU/memory measurements, rapid native switching/navigation races,
  live network-failure injection, and native chat-result rendering remain follow-up checks.

## Why other guide techniques were deferred

- Result cards are bounded (stay-put plus at most one suggestion per mode); reuse or
  virtualization adds complexity without a demonstrated benefit for this collection.
  Chat history is unbounded and remains a candidate for a separately measured lazy list.
- No measured CPU bottleneck justifies TaskPool/Worker or Sendable migration. Network calls
  already use asynchronous APIs. Parallel route requests need explicit rate/concurrency limits.
- Retain snapshot ownership for plan geometry; do not change `@Prop` to shared mutable
  references solely to reduce copying.
- No speculative Web prefetch, prerender, DisplaySync, or broad dynamic-import migration:
  measure device startup and memory before adding earlier work or new lifecycle complexity.

## Broader native profiling protocol (follow-up)

Use the same API-24 phone, build mode, settings, and fixture before/after. Record cold-launch
and first-map-frame times, frame loss during route switching, process CPU, and peak memory.
Repeat at least five times; report medians and range. Keep keys and precise personal locations
out of captures and logs.

1. Start without keys; the offline schematic must paint on first entry.
2. Assign driver and passenger repeatedly; final pins match the latest selection.
3. Plan, switch all cards rapidly, then confirm; routes and ETAs match the selected snapshot.
4. Repeat through offline chat and the locked-plan page; sharing preserves grounded fields.
5. Leave during the 80 ms map deferral, return, and repeat planning; no stale mount or crash.
6. Repeat with configured live AMap, then network failure; fallback remains usable.
7. Compare measurements; reconsider retry removal if first-paint reliability regresses.


The live native smoke test uses the device's existing map configuration. The offline case
temporarily clears provider settings and restores the original settings in a `finally` block.
The production fixture toggle has been removed.
Screenshots are written to the application sandbox `files/meetagent-{home,form,plan,locked}.png`;
they are test artifacts, not committed assets. The test creates an in-memory locked session.

## Semifinal visual cleanup — 2026-09-17

Removed the full-screen decorative photo and its overlay. Shared surfaces are light and
opaque; map reload coalescing remains owned by `InteractiveMapView`. No parent refresh timers
were introduced. Native screen checks cover map selection, live results, lock and navigation;
this establishes functional/rendering correctness, not measured frame-rate improvement.

Verification: app and test HAP SDK builds passed; 28 domain tests, 6 Node host tests, and
4 native emulator tests passed. Screenshots were inspected for the home map, planning form,
results, meeting-point details, locked trip, assistant, settings, and offline states. Offline
selection labels and estimate badges were checked, and original settings were restored.
Physical-phone validation and frame-rate profiling remain outstanding.

Visual evidence can be exported from the debug app after the native suite, for example:

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc file recv \
  -b com.rinalic.meetAgentHarmony /data/storage/el2/base/files/meetagent-home.png /tmp/meetagent-home.png
```

The default AMap palette is softened with a map-layer saturation filter; route coordinates,
labels, and vendor attribution are unchanged. Style reference:
[AMap official map themes](https://lbs.amap.com/demo/javascript-api-v2/example/personalized-map/set-theme-style/).

## Rail-station planning verification — 2026-09-17

Station POI search adds one bounded request per planning run. Routing still evaluates at
most four meeting candidates. Host tests exercise actual ArkTS station eligibility and
AMap response parsing (including rail alternatives, malformed durations, and station types).
The emulator planning flow selected 地铁优先 and displayed a live station-entrance candidate;
public transport labels and strategy controls were visually checked. This is functional
validation, not a device performance benchmark.

Verification passed: app/test SDK builds, 34 domain tests, 10 host tests and 4 native
emulator tests. Offline test settings were restored; no physical-device benchmark was run.

## Passenger route details and location entry — 2026-09-18

The route sheet reuses the selected AMap transit response; opening it issues no extra
routing requests. It renders ordered walking and transit legs and explicitly handles
missing itineraries. Native endpoint search replaces the embedded map search controls.
Home enables the traffic layer initially. Planning adds a single foreground location
request only when an endpoint is unset, plus passenger-city lookup when configured.

Host verification covers itinerary parsing, snapshot isolation, permission denial,
coordinate conversion and preservation of manual endpoints (16 tests). Domain suite:
35 tests. App and native test HAPs build with the SDK. The emulator permission dialog
was exercised; no usable location fix was returned, and manual selection remained
available. Successful native GPS fixes still need a physical-device check. These are
functional checks, not startup or frame-rate measurements.

Final native suite: 4/4 passed. Live POI searches, map selection, a metro-first
journey from the Xi’an North Station area, the populated passenger itinerary, confirmation/lock,
main tabs and missing-map-key blocking were exercised. The key is stored only in the
emulator settings and was restored after the missing-key test.

## Inline itinerary and route styling — 2026-09-18

The passenger timeline shares the result page scroll and has no modal or nested scroll.
Route drawing reuses planning responses: opening details or selecting a card performs
no additional routing request. TMC segments, transit geometry and stops are copied into
plan snapshots. The map preserves polyline vertices instead of dropping to 64 points,
so road bends remain aligned with traffic segments. Fitting uses route polylines only,
excluding ETA callout dimensions. Existing map reload batching and disposal remain.

Host checks cover traffic status colors and geometry, distinct transit colors, dashed
walking, grounded ETA labels, HTML escaping and snapshot isolation (19 tests). Domain
checks include candidate-specific traffic and absent traffic on estimates (36 tests).
These establish behavior, not a measured frame-rate or memory improvement.

Both app and native test HAP SDK builds passed. The final emulator suite passed 4/4
tests, including live metro-first planning, inline itinerary scrolling and plan locking.
Visual inspection confirmed three distinct metro line colors, traffic-colored driving
segments, readable ETA callouts and walking transfers in the normal page scroll.
Route traffic is the provider response captured when planning, not a continuously
refreshed traffic feed. No physical-device performance benchmark was run.

## Agent activity and location pins — 2026-09-18

Agent activity is emitted at existing request boundaries, without polling, extra model
requests or simulated progress timers. The indicator remains outside the chat scroll
so long histories do not hide it. Shared map pins use CSS content and preserve marker
reuse when endpoints move. Host verification covers request/tool progress ordering and
ignoring callbacks after cancellation. This is functional validation, not a rendering
performance benchmark.

Verification: app/test HAP SDK builds and 20 host tests passed. The emulator exercised
configured chat against an intentionally unavailable local proxy: the progress strip
remained visible during engine fallback and disappeared when results arrived. A mocked
LLM/tool loop verifies model-request and traffic-request status ordering; a live LLM
provider was not required for this check. Visual review also moved ETA callouts apart
from the larger location pins and put location markers above intermediate route stops.
The final emulator suite passed 5/5 tests after the callout adjustment; result-map
screenshots confirmed both pin labels and ETA tags remained readable.

## Zoom-aware location pins — 2026-09-18

The map's zoomchange event updates two existing marker elements with CSS transforms;
there is no Web reload, route request, timer or marker reconstruction. Size changes
are quantized to 2% steps and identical styles skip DOM writes. The transform origin
matches the marker's coordinate anchor. Labels remain 12 screen pixels when visible.
The event contract follows the [AMap JSAPI zoom example](https://lbs.amap.com/demo/javascript-api-v2/example/event/event-map-zoom).
Host checks cover bounded scaling, both roles, label visibility and redundant updates.
Native smoke includes pinch-out/in screenshots; these checks do not measure frame rate.
Verification passed: app/test HAP SDK builds, eight map host tests and five native
emulator tests. Screenshots show reduced marker sizes at city/regional zoom levels;
pinch gestures retain the selected plan and route. Full-size and label thresholds are
also checked by the host test against the generated renderer.
