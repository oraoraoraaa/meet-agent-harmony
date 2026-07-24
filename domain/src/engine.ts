/**
 * Route-interception engine (pure).
 * Numbers only — no I/O, no LLM.
 */

import type { EngineConfig } from './engineConfig.ts';
import { DEFAULT_ENGINE_CONFIG } from './engineConfig.ts';
import type {
  Candidate,
  Constraints,
  EvaluatedOption,
  GeoPoint,
  MobilityMode,
  RoutePoint,
} from './models.ts';
import { haversineM } from './geo.ts';

export type { EngineConfig };
export { DEFAULT_ENGINE_CONFIG };

export function modePenaltyMin(mode: MobilityMode, cfg: EngineConfig = DEFAULT_ENGINE_CONFIG): number {
  switch (mode) {
    case 'walking':
      return 0;
    case 'bicycle':
      return cfg.bicyclePenaltyMin;
    case 'transit':
      return cfg.transitPenaltyMin;
  }
}

export function scoreOption(
  driverEtaMin: number,
  passengerEtaMin: number,
  mode: MobilityMode,
  cfg: EngineConfig = DEFAULT_ENGINE_CONFIG,
): number {
  const completionMin = Math.max(driverEtaMin, passengerEtaMin);
  return completionMin + cfg.passengerBurdenWeight * passengerEtaMin + modePenaltyMin(mode, cfg);
}

export function reachableModes(
  distanceM: number,
  cfg: EngineConfig = DEFAULT_ENGINE_CONFIG,
): MobilityMode[] {
  const modes: MobilityMode[] = [];
  if (distanceM <= cfg.walkReachM) modes.push('walking');
  if (distanceM <= cfg.bicycleReachM) modes.push('bicycle');
  if (distanceM >= cfg.transitMinM && distanceM <= cfg.transitReachM) modes.push('transit');
  return modes;
}

/**
 * Sample meeting candidates along the driver route toward the passenger.
 * Filters: min passenger move, min driver saving, spacing, max count.
 * Prefers points that keep max(driverEta, roughWalkEta) low while still saving driver time.
 */
export function generateRouteCandidates(
  route: readonly RoutePoint[],
  passenger: GeoPoint,
  cfg: EngineConfig = DEFAULT_ENGINE_CONFIG,
): Candidate[] {
  if (route.length < 2) return [];

  const end = route[route.length - 1]!;
  const endDriverSecs = end.driverSecs;
  const maxReach = Math.max(cfg.walkReachM, cfg.bicycleReachM, cfg.transitReachM);

  type Raw = Candidate & { metersFromStart: number; roughScore: number };
  const raw: Raw[] = [];

  for (let i = 0; i < route.length - 1; i++) {
    const rp = route[i]!;
    const passengerStraightM = haversineM(rp.point, passenger);
    if (passengerStraightM < cfg.minPassengerMoveM) continue;
    if (passengerStraightM > maxReach) continue;

    const driverSavingSecs = endDriverSecs - rp.driverSecs;
    if (driverSavingSecs < cfg.minDriverSavingSecs) continue;

    const driverEtaMin = rp.driverSecs / 60;
    // rough walk-speed proxy for ranking density (~4.5 km/h)
    const roughPassengerMin = (passengerStraightM / 1000 / 4.5) * 60;
    const roughScore = Math.max(driverEtaMin, roughPassengerMin) + 0.1 * roughPassengerMin;

    raw.push({
      routeIndex: i,
      point: rp.point,
      driverEtaMin,
      passengerStraightM,
      metersFromStart: rp.metersFromStart,
      roughScore,
    });
  }

  if (raw.length === 0) return [];

  // Greedy spacing along route meters, taking better roughScore first
  raw.sort((a, b) => a.roughScore - b.roughScore || a.passengerStraightM - b.passengerStraightM);

  const selected: Raw[] = [];
  for (const c of raw) {
    const tooClose = selected.some(
      (s) => Math.abs(s.metersFromStart - c.metersFromStart) < cfg.minCandidateSpacingM,
    );
    if (tooClose) continue;
    selected.push(c);
    if (selected.length >= cfg.maxCandidates) break;
  }

  // Stable order along route for determinism
  selected.sort((a, b) => a.metersFromStart - b.metersFromStart);

  return selected.map((c) => ({
    routeIndex: c.routeIndex,
    point: c.point,
    driverEtaMin: c.driverEtaMin,
    passengerStraightM: c.passengerStraightM,
  }));
}

export function rankOptions(options: readonly EvaluatedOption[]): EvaluatedOption[] {
  return [...options].sort((a, b) => {
    if (a.score !== b.score) return a.score - b.score;
    if (a.passengerEtaMin !== b.passengerEtaMin) return a.passengerEtaMin - b.passengerEtaMin;
    return a.driverEtaMin - b.driverEtaMin;
  });
}

export function bestPerMode(ranked: readonly EvaluatedOption[]): EvaluatedOption[] {
  const seen = new Set<MobilityMode>();
  const out: EvaluatedOption[] = [];
  for (const option of ranked) {
    if (seen.has(option.mode)) continue;
    seen.add(option.mode);
    out.push(option);
  }
  return out;
}

/** Returns the best option if it beats stay-put by minImprovementMin; else null. */
export function decideSwitch(
  baselineDriverEtaMin: number,
  ranked: readonly EvaluatedOption[],
  cfg: EngineConfig = DEFAULT_ENGINE_CONFIG,
): EvaluatedOption | null {
  const best = ranked[0];
  if (!best) return null;
  if (best.score <= baselineDriverEtaMin - cfg.minImprovementMin) return best;
  return null;
}

export function allowedModesFromConstraints(
  constraints: Constraints | undefined,
  distanceM: number,
  cfg: EngineConfig = DEFAULT_ENGINE_CONFIG,
): MobilityMode[] {
  const reachable = reachableModes(distanceM, cfg);
  const allow = constraints?.allowedModes ?? (['walking', 'bicycle', 'transit'] as MobilityMode[]);
  const avoidTransit = constraints?.avoidTransit === true;
  return reachable.filter((m) => {
    if (!allow.includes(m)) return false;
    if (avoidTransit && m === 'transit') return false;
    return true;
  });
}

/** Soft cap filters after scoring (walk/bike max minutes). */
export function passesSoftCaps(
  mode: MobilityMode,
  passengerEtaMin: number,
  constraints: Constraints | undefined,
): boolean {
  if (!constraints) return true;
  if (mode === 'walking' && constraints.maxPassengerWalkMin !== undefined) {
    if (passengerEtaMin > constraints.maxPassengerWalkMin) return false;
  }
  if (mode === 'bicycle' && constraints.maxPassengerBikeMin !== undefined) {
    if (passengerEtaMin > constraints.maxPassengerBikeMin) return false;
  }
  return true;
}

export function sliceDriverPolyline(
  full: readonly GeoPoint[],
  routeIndex: number,
): GeoPoint[] {
  if (full.length === 0) return [];
  const end = Math.min(full.length - 1, Math.max(0, routeIndex));
  return full.slice(0, end + 1).map((p) => ({ lon: p.lon, lat: p.lat }));
}
