# MeetAgent review information

Bundle: `com.rinalic.meetAgentHarmony`  
AGC APP ID: `6917616810342569054`

MeetAgent helps a driver and passenger choose a meeting point at the start of a trip.
Planning takes place on one device. It compares waiting, walking, cycling and public
transport, including a metro-first preference. Confirming a plan locks the meeting point.

## Review flow

1. Open Settings and configure an AMap Web Service key, then save. A fresh installation
   intentionally blocks map planning until a key is supplied. The publisher must provide
   any reviewer credentials privately through AGC; none are included in this document.
2. On 地图, tap each location row to search or select locations on the map.
3. Tap 规划会合路线, choose transport preferences, then 开始路线优化.
4. Inspect recommendations, route overlays and inline public transport directions.
5. Confirm and lock the chosen plan, then check 行程 and copy/share/open-map actions.
6. Check Settings → 隐私声明. The app links to the publisher's AGC-hosted declaration.
7. Optional: configure an OpenAI-compatible LLM in Settings to test chat planning.
   During requests, activity messages show progress. LLM failure falls back to the
   local engine using the current structured preferences.

Location permission is requested for the optional current-location endpoint feature.
Manual location selection remains available if permission or a location fix is unavailable.
Route estimates are labeled when provider routing fails. No account registration or
payment is required by this app. Third-party map/LLM access may require separate credentials.

Current minimum supported system is HarmonyOS 6.1.1 (API 24).
