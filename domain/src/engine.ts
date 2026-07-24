/**
 * Route-interception engine (scaffold).
 *
 * Phase 1 will implement:
 * - generateRouteCandidates
 * - reachableModes
 * - scoreOption / rankOptions / bestPerMode
 * - decide (stay-put threshold)
 *
 * Keep pure: no I/O, no LLM.
 */

import type { EngineConfig } from './engineConfig.ts';
import { DEFAULT_ENGINE_CONFIG } from './engineConfig.ts';
import type {
  Candidate,
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
 * Placeholder: returns empty until Phase 1 lands full candidate generation.
 * Signature is stable for callers.
 */
export function generateRouteCandidates(
  route: readonly RoutePoint[],
  passenger: GeoPoint,
  cfg: EngineConfig = DEFAULT_ENGINE_CONFIG,
): Candidate[] {
  if (route.length === 0) return [];
  // TODO(phase-1): implement spacing / reach / driver-saving filters.
  void passenger;
  void cfg;
  void haversineM;
  return [];
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
