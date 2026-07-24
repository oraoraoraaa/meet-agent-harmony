import { defaultEngineConfig, EngineConfig } from './EngineConfig';
import { haversineM } from './Geo';
import {
  Candidate,
  Constraints,
  EvaluatedOption,
  GeoPoint,
  MODE_BICYCLE,
  MODE_TRANSIT,
  MODE_WALKING,
  MobilityMode,
  RoutePoint
} from './Models';

export function modePenaltyMin(mode: MobilityMode, cfg: EngineConfig = defaultEngineConfig()): number {
  if (mode === MODE_WALKING) {
    return 0;
  }
  if (mode === MODE_BICYCLE) {
    return cfg.bicyclePenaltyMin;
  }
  if (mode === MODE_TRANSIT) {
    return cfg.transitPenaltyMin;
  }
  return 0;
}

export function scoreOption(
  driverEtaMin: number,
  passengerEtaMin: number,
  mode: MobilityMode,
  cfg: EngineConfig = defaultEngineConfig()
): number {
  const completionMin: number = Math.max(driverEtaMin, passengerEtaMin);
  return completionMin + cfg.passengerBurdenWeight * passengerEtaMin + modePenaltyMin(mode, cfg);
}

export function reachableModes(distanceM: number, cfg: EngineConfig = defaultEngineConfig()): MobilityMode[] {
  const modes: MobilityMode[] = [];
  if (distanceM <= cfg.walkReachM) {
    modes.push(MODE_WALKING);
  }
  if (distanceM <= cfg.bicycleReachM) {
    modes.push(MODE_BICYCLE);
  }
  if (distanceM >= cfg.transitMinM && distanceM <= cfg.transitReachM) {
    modes.push(MODE_TRANSIT);
  }
  return modes;
}

class RawCandidate {
  routeIndex: number = 0;
  point: GeoPoint = new GeoPoint();
  driverEtaMin: number = 0;
  passengerStraightM: number = 0;
  metersFromStart: number = 0;
  roughScore: number = 0;
}

export function generateRouteCandidates(
  route: RoutePoint[],
  passenger: GeoPoint,
  cfg: EngineConfig = defaultEngineConfig()
): Candidate[] {
  if (route.length < 2) {
    return [];
  }

  const end: RoutePoint = route[route.length - 1];
  const endDriverSecs: number = end.driverSecs;
  const maxReach: number = Math.max(cfg.walkReachM, cfg.bicycleReachM, cfg.transitReachM);
  const raw: RawCandidate[] = [];

  for (let i = 0; i < route.length - 1; i++) {
    const rp: RoutePoint = route[i];
    const passengerStraightM: number = haversineM(rp.point, passenger);
    if (passengerStraightM < cfg.minPassengerMoveM) {
      continue;
    }
    if (passengerStraightM > maxReach) {
      continue;
    }
    const driverSavingSecs: number = endDriverSecs - rp.driverSecs;
    if (driverSavingSecs < cfg.minDriverSavingSecs) {
      continue;
    }
    const driverEtaMin: number = rp.driverSecs / 60;
    const roughPassengerMin: number = (passengerStraightM / 1000 / 4.5) * 60;
    const roughScore: number = Math.max(driverEtaMin, roughPassengerMin) + 0.1 * roughPassengerMin;
    const item: RawCandidate = new RawCandidate();
    item.routeIndex = i;
    item.point = rp.point;
    item.driverEtaMin = driverEtaMin;
    item.passengerStraightM = passengerStraightM;
    item.metersFromStart = rp.metersFromStart;
    item.roughScore = roughScore;
    raw.push(item);
  }

  if (raw.length === 0) {
    return [];
  }

  raw.sort((a: RawCandidate, b: RawCandidate): number => {
    if (a.roughScore !== b.roughScore) {
      return a.roughScore - b.roughScore;
    }
    return a.passengerStraightM - b.passengerStraightM;
  });

  const selected: RawCandidate[] = [];
  for (let i = 0; i < raw.length; i++) {
    const c: RawCandidate = raw[i];
    let tooClose: boolean = false;
    for (let j = 0; j < selected.length; j++) {
      const s: RawCandidate = selected[j];
      if (Math.abs(s.metersFromStart - c.metersFromStart) < cfg.minCandidateSpacingM) {
        tooClose = true;
        break;
      }
    }
    if (tooClose) {
      continue;
    }
    selected.push(c);
    if (selected.length >= cfg.maxCandidates) {
      break;
    }
  }

  selected.sort((a: RawCandidate, b: RawCandidate): number => {
    return a.metersFromStart - b.metersFromStart;
  });

  const out: Candidate[] = [];
  for (let i = 0; i < selected.length; i++) {
    const c: RawCandidate = selected[i];
    const cand: Candidate = new Candidate();
    cand.routeIndex = c.routeIndex;
    cand.point = c.point;
    cand.driverEtaMin = c.driverEtaMin;
    cand.passengerStraightM = c.passengerStraightM;
    out.push(cand);
  }
  return out;
}

export function rankOptions(options: EvaluatedOption[]): EvaluatedOption[] {
  const copy: EvaluatedOption[] = options.slice();
  copy.sort((a: EvaluatedOption, b: EvaluatedOption): number => {
    if (a.score !== b.score) {
      return a.score - b.score;
    }
    if (a.passengerEtaMin !== b.passengerEtaMin) {
      return a.passengerEtaMin - b.passengerEtaMin;
    }
    return a.driverEtaMin - b.driverEtaMin;
  });
  return copy;
}

export function bestPerMode(ranked: EvaluatedOption[]): EvaluatedOption[] {
  const seen: string[] = [];
  const out: EvaluatedOption[] = [];
  for (let i = 0; i < ranked.length; i++) {
    const option: EvaluatedOption = ranked[i];
    let already: boolean = false;
    for (let j = 0; j < seen.length; j++) {
      if (seen[j] === option.mode) {
        already = true;
        break;
      }
    }
    if (already) {
      continue;
    }
    seen.push(option.mode);
    out.push(option);
  }
  return out;
}

/** Returns winning option, or undefined when stay-put should win. */
export function decideSwitch(
  baselineDriverEtaMin: number,
  ranked: EvaluatedOption[],
  cfg: EngineConfig = defaultEngineConfig()
): EvaluatedOption | undefined {
  if (ranked.length === 0) {
    return undefined;
  }
  const best: EvaluatedOption = ranked[0];
  if (best.score <= baselineDriverEtaMin - cfg.minImprovementMin) {
    return best;
  }
  return undefined;
}

export function allowedModesFromConstraints(
  constraints: Constraints,
  distanceM: number,
  cfg: EngineConfig = defaultEngineConfig()
): MobilityMode[] {
  const reachable: MobilityMode[] = reachableModes(distanceM, cfg);
  const allow: MobilityMode[] = constraints.allowedModes;
  const out: MobilityMode[] = [];
  for (let i = 0; i < reachable.length; i++) {
    const m: MobilityMode = reachable[i];
    let allowed: boolean = false;
    for (let j = 0; j < allow.length; j++) {
      if (allow[j] === m) {
        allowed = true;
        break;
      }
    }
    if (!allowed) {
      continue;
    }
    if (constraints.avoidTransit && m === MODE_TRANSIT) {
      continue;
    }
    out.push(m);
  }
  return out;
}

export function passesSoftCaps(
  mode: MobilityMode,
  passengerEtaMin: number,
  constraints: Constraints
): boolean {
  if (mode === MODE_WALKING && constraints.maxPassengerWalkMin >= 0) {
    if (passengerEtaMin > constraints.maxPassengerWalkMin) {
      return false;
    }
  }
  if (mode === MODE_BICYCLE && constraints.maxPassengerBikeMin >= 0) {
    if (passengerEtaMin > constraints.maxPassengerBikeMin) {
      return false;
    }
  }
  return true;
}

export function sliceDriverPolyline(full: GeoPoint[], routeIndex: number): GeoPoint[] {
  if (full.length === 0) {
    return [];
  }
  const end: number = Math.min(full.length - 1, Math.max(0, routeIndex));
  const out: GeoPoint[] = [];
  for (let i = 0; i <= end; i++) {
    out.push(new GeoPoint(full[i].lon, full[i].lat));
  }
  return out;
}
