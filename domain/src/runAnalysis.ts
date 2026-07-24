/**
 * Orchestrate route + passenger ETAs → RecommendationSet.
 * Inject providers so live HTTP or estimates can plug in.
 */

import {
  allowedModesFromConstraints,
  bestPerMode,
  decideSwitch,
  DEFAULT_ENGINE_CONFIG,
  generateRouteCandidates,
  passesSoftCaps,
  rankOptions,
  scoreOption,
  sliceDriverPolyline,
  type EngineConfig,
} from './engine.ts';
import { buildStraightDrivingRoute, estimatePassengerPath } from './estimate.ts';
import type {
  DataSource,
  EvaluatedOption,
  GeoPoint,
  MobilityMode,
  NamedPoint,
  RecommendationSet,
  RoutePoint,
  Scenario,
  StayPutSuggestion,
  Suggestion,
} from './models.ts';

export interface DrivingRouteResult {
  readonly polyline: readonly GeoPoint[];
  readonly route: readonly RoutePoint[];
  readonly dataSource: DataSource;
}

export interface PassengerPathResult {
  readonly etaMin: number;
  readonly polyline: readonly GeoPoint[];
  readonly dataSource: DataSource;
}

export interface AnalysisProviders {
  getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> | DrivingRouteResult;
  getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city?: string,
  ): Promise<PassengerPathResult> | PassengerPathResult;
}

export interface AnalysisOptions {
  readonly config?: EngineConfig;
  readonly now?: () => Date;
}

function asNamed(point: GeoPoint, name?: string, address?: string): NamedPoint {
  return {
    lon: point.lon,
    lat: point.lat,
    name,
    address,
  };
}

function modeLabelZh(mode: MobilityMode): string {
  switch (mode) {
    case 'walking':
      return '步行';
    case 'bicycle':
      return '骑行';
    case 'transit':
      return '公交';
  }
}

function mergeDataSource(a: DataSource, b: DataSource): DataSource {
  if (a === 'live' && b === 'live') return 'live';
  if (a === 'estimate' && b === 'estimate') return 'estimate';
  return 'live_with_fallback';
}

function templateStayRationale(driverEtaMin: number): string {
  return `乘客原地等待；司机全程约 ${driverEtaMin.toFixed(0)} 分钟到达乘客位置。`;
}

function buildMoveRationale(
  mode: MobilityMode,
  driverEtaMin: number,
  passengerEtaMin: number,
  driverSavedMin: number,
): string {
  const completion = Math.max(driverEtaMin, passengerEtaMin);
  const savePart =
    driverSavedMin > 0.4 ? `，较原地等待为司机节省约 ${driverSavedMin.toFixed(0)} 分钟。` : '。';
  return (
    `乘客${modeLabelZh(mode)}约 ${passengerEtaMin.toFixed(0)} 分钟至会合点，` +
    `司机约 ${driverEtaMin.toFixed(0)} 分钟；会合完成约 ${completion.toFixed(0)} 分钟` +
    savePart
  );
}

/**
 * Core analysis: pure ranking once routes/ETAs are provided.
 */
export async function runAnalysis(
  scenario: Scenario,
  providers: AnalysisProviders,
  options: AnalysisOptions = {},
): Promise<RecommendationSet> {
  const cfg = options.config ?? DEFAULT_ENGINE_CONFIG;
  const now = options.now ?? (() => new Date());

  const driver = scenario.driver;
  const passenger = scenario.passenger;

  const driving = await providers.getDrivingRoute(driver, passenger);
  const route = driving.route;
  const fullPolyline = driving.polyline.map((p) => ({ lon: p.lon, lat: p.lat }));
  let dataSource: DataSource = driving.dataSource;

  if (route.length === 0) {
    const stay: StayPutSuggestion = {
      recommended: true,
      driverEtaMin: 0,
      completionMin: 0,
      meetingPoint: asNamed(passenger, passenger.name, passenger.address),
      rationale: '起终点相同或路线不可用，保持原地会合。',
      driverRoutePolyline: fullPolyline.length > 0 ? fullPolyline : [driver, passenger],
    };
    return {
      generatedAt: now().toISOString(),
      dataSource,
      passengerStart: passenger,
      driverStart: driver,
      stayPut: stay,
      suggestions: [],
    };
  }

  const end = route[route.length - 1]!;
  const baselineDriverEtaMin = end.driverSecs / 60;

  type EvalWithPath = EvaluatedOption & { passengerPolyline: readonly GeoPoint[] };
  const evaluated: EvalWithPath[] = [];

  const candidates = generateRouteCandidates(route, passenger, cfg);
  for (const cand of candidates) {
    const modes = allowedModesFromConstraints(scenario.constraints, cand.passengerStraightM, cfg);
    for (const mode of modes) {
      const path = await providers.getPassengerPath(mode, passenger, cand.point, scenario.city);
      dataSource = mergeDataSource(dataSource, path.dataSource);
      if (!passesSoftCaps(mode, path.etaMin, scenario.constraints)) continue;

      const score = scoreOption(cand.driverEtaMin, path.etaMin, mode, cfg);
      evaluated.push({
        meetingPoint: cand.point,
        routeIndex: cand.routeIndex,
        mode,
        driverEtaMin: cand.driverEtaMin,
        passengerEtaMin: path.etaMin,
        completionMin: Math.max(cand.driverEtaMin, path.etaMin),
        score,
        passengerPolyline: path.polyline,
      });
    }
  }

  const ranked = rankOptions(evaluated);
  const perMode = bestPerMode(ranked);
  const winner = decideSwitch(baselineDriverEtaMin, ranked, cfg);

  const suggestions: Suggestion[] = perMode.map((opt) => {
    const withPath = evaluated.find(
      (e) => e.mode === opt.mode && e.routeIndex === opt.routeIndex && e.score === opt.score,
    );
    const passengerPolyline = withPath?.passengerPolyline ?? [passenger, opt.meetingPoint];
    const driverSavedMin = Math.max(0, baselineDriverEtaMin - opt.driverEtaMin);
    const isRec =
      winner !== null &&
      winner.mode === opt.mode &&
      winner.routeIndex === opt.routeIndex &&
      Math.abs(winner.score - opt.score) < 1e-9;

    return {
      mode: opt.mode,
      recommended: isRec,
      meetingPoint: asNamed(opt.meetingPoint, `会合点·${modeLabelZh(opt.mode)}`, undefined),
      driverEtaMin: opt.driverEtaMin,
      passengerEtaMin: opt.passengerEtaMin,
      completionMin: opt.completionMin,
      driverSavedMin,
      score: opt.score,
      rationale: buildMoveRationale(opt.mode, opt.driverEtaMin, opt.passengerEtaMin, driverSavedMin),
      driverRoutePolyline: sliceDriverPolyline(fullPolyline, opt.routeIndex),
      passengerPathPolyline: passengerPolyline.map((p) => ({ lon: p.lon, lat: p.lat })),
    };
  });

  const recommendStay = winner === null;

  // Exactly one recommended flag
  if (recommendStay) {
    for (let i = 0; i < suggestions.length; i++) {
      if (suggestions[i]!.recommended) {
        suggestions[i] = { ...suggestions[i]!, recommended: false };
      }
    }
  } else {
    let found = false;
    for (let i = 0; i < suggestions.length; i++) {
      if (suggestions[i]!.recommended) {
        if (found) {
          suggestions[i] = { ...suggestions[i]!, recommended: false };
        } else {
          found = true;
        }
      }
    }
    if (!found && suggestions.length > 0) {
      // Prefer winner mode if present
      let idx = 0;
      if (winner) {
        const m = suggestions.findIndex((s) => s.mode === winner.mode);
        if (m >= 0) idx = m;
      }
      suggestions[idx] = { ...suggestions[idx]!, recommended: true };
    }
  }

  const stayPut: StayPutSuggestion = {
    recommended: recommendStay,
    driverEtaMin: baselineDriverEtaMin,
    completionMin: baselineDriverEtaMin,
    meetingPoint: asNamed(passenger, passenger.name ?? '乘客位置', passenger.address),
    rationale: templateStayRationale(baselineDriverEtaMin),
    driverRoutePolyline: fullPolyline.length > 0 ? fullPolyline : [driver, passenger],
  };

  return {
    generatedAt: now().toISOString(),
    dataSource,
    passengerStart: passenger,
    driverStart: driver,
    stayPut,
    suggestions,
  };
}

/** Convenience: fully offline estimate analysis. */
export async function runEstimateAnalysis(
  scenario: Scenario,
  options: AnalysisOptions = {},
): Promise<RecommendationSet> {
  return runAnalysis(
    scenario,
    {
      getDrivingRoute(from, to) {
        const built = buildStraightDrivingRoute(from, to);
        return {
          polyline: built.polyline,
          route: built.route,
          dataSource: 'estimate',
        };
      },
      getPassengerPath(mode, from, to) {
        const path = estimatePassengerPath(mode, from, to);
        return {
          etaMin: path.etaMin,
          polyline: path.polyline,
          dataSource: 'estimate',
        };
      },
    },
    options,
  );
}
