# Semifinal presentation flow

The production app has no demo mode or prefilled trips. Rehearse with actual map selections.

1. Open **地图**. Search for the driver's origin; choose **设为司机出发地**.
2. Search for the passenger; choose **设为乘客位置**.
3. Tap **规划会合路线**, choose allowed travel modes and walking limit, then **开始路线优化**.
4. Compare tool-backed arrival times, inspect routes, and explain the visible real/estimate badge.
5. Select a plan and confirm it. **行程** holds the fixed meeting point; share or open navigation.
6. Use **助手** for natural-language constraints when an LLM is configured. Offline, its action opens the structured preference form.
7. To show graceful degradation, test separately without a map key. The schematic is explicitly labeled and does not claim to display roads.

Before presenting: verify map/LLM credentials on the actual device, prepare two real pickup locations,
and check network connectivity. Never put credentials in recordings, screenshots, or source control.
The meeting point changes only after explicit re-planning.
