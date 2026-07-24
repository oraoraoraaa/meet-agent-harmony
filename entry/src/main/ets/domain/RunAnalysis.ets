import {
  allowedModesFromConstraints,
  bestPerMode,
  decideSwitch,
  generateRouteCandidates,
  passesSoftCaps,
  rankOptions,
  scoreOption,
  sliceDriverPolyline
} from './Engine';
import { defaultEngineConfig, EngineConfig } from './EngineConfig';
import { buildStraightDrivingRoute, estimatePassengerPath, PassengerPathEstimate, StraightRouteBuild } from './Estimate';
import {
  Candidate,
  DATA_ESTIMATE,
  DATA_LIVE,
  DATA_LIVE_FALLBACK,
  DataSource,
  EvaluatedOption,
  GeoPoint,
  modeLabelZh,
  NamedPoint,
  RecommendationSet,
  RoutePoint,
  Scenario,
  StayPutSuggestion,
  Suggestion,
  MobilityMode
} from './Models';

export class DrivingRouteResult {
  polyline: GeoPoint[] = [];
  route: RoutePoint[] = [];
  dataSource: DataSource = DATA_ESTIMATE;
}

export class PassengerPathResult {
  etaMin: number = 0;
  polyline: GeoPoint[] = [];
  dataSource: DataSource = DATA_ESTIMATE;
}

export interface AnalysisProviders {
  getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult>;

  getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string
  ): Promise<PassengerPathResult>;
}

function asNamed(point: GeoPoint, name: string, address: string): NamedPoint {
  return new NamedPoint(point.lon, point.lat, name, address);
}

function mergeDataSource(a: DataSource, b: DataSource): DataSource {
  if (a === DATA_LIVE && b === DATA_LIVE) {
    return DATA_LIVE;
  }
  if (a === DATA_ESTIMATE && b === DATA_ESTIMATE) {
    return DATA_ESTIMATE;
  }
  return DATA_LIVE_FALLBACK;
}

function templateStayRationale(driverEtaMin: number): string {
  return `乘客原地等待；司机全程约 ${driverEtaMin.toFixed(0)} 分钟到达乘客位置。`;
}

function buildMoveRationale(
  mode: MobilityMode,
  driverEtaMin: number,
  passengerEtaMin: number,
  driverSavedMin: number
): string {
  const completion: number = Math.max(driverEtaMin, passengerEtaMin);
  const savePart: string =
    driverSavedMin > 0.4 ? `，较原地等待为司机节省约 ${driverSavedMin.toFixed(0)} 分钟。` : '。';
  return `乘客${modeLabelZh(mode)}约 ${passengerEtaMin.toFixed(0)} 分钟至会合点，` +
    `司机约 ${driverEtaMin.toFixed(0)} 分钟；会合完成约 ${completion.toFixed(0)} 分钟` +
    savePart;
}

function copyPolyline(src: GeoPoint[]): GeoPoint[] {
  const out: GeoPoint[] = [];
  for (let i = 0; i < src.length; i++) {
    out.push(new GeoPoint(src[i].lon, src[i].lat));
  }
  return out;
}

export async function runAnalysis(
  scenario: Scenario,
  providers: AnalysisProviders,
  cfg: EngineConfig = defaultEngineConfig(),
  generatedAt: string = new Date().toISOString()
): Promise<RecommendationSet> {
  const driver: NamedPoint = scenario.driver;
  const passenger: NamedPoint = scenario.passenger;
  const driverGeo: GeoPoint = driver.toGeo();
  const passengerGeo: GeoPoint = passenger.toGeo();

  const driving: DrivingRouteResult = await providers.getDrivingRoute(driverGeo, passengerGeo);
  const route: RoutePoint[] = driving.route;
  const fullPolyline: GeoPoint[] = copyPolyline(driving.polyline);
  let dataSource: DataSource = driving.dataSource;

  const result: RecommendationSet = new RecommendationSet();
  result.generatedAt = generatedAt;
  result.passengerStart = passenger;
  result.driverStart = driver;

  if (route.length === 0) {
    const stay: StayPutSuggestion = new StayPutSuggestion();
    stay.recommended = true;
    stay.driverEtaMin = 0;
    stay.completionMin = 0;
    stay.meetingPoint = asNamed(passengerGeo, passenger.name, passenger.address);
    stay.rationale = '起终点相同或路线不可用，保持原地会合。';
    stay.driverRoutePolyline = fullPolyline.length > 0 ? fullPolyline : [driverGeo, passengerGeo];
    result.dataSource = dataSource;
    result.stayPut = stay;
    result.suggestions = [];
    return result;
  }

  const end: RoutePoint = route[route.length - 1];
  const baselineDriverEtaMin: number = end.driverSecs / 60;
  const candidates: Candidate[] = generateRouteCandidates(route, passengerGeo, cfg);
  const evaluated: EvaluatedOption[] = [];

  for (let i = 0; i < candidates.length; i++) {
    const cand: Candidate = candidates[i];
    const modes: MobilityMode[] = allowedModesFromConstraints(scenario.constraints, cand.passengerStraightM, cfg);
    for (let m = 0; m < modes.length; m++) {
      const mode: MobilityMode = modes[m];
      const path: PassengerPathResult =
        await providers.getPassengerPath(mode, passengerGeo, cand.point, scenario.city);
      dataSource = mergeDataSource(dataSource, path.dataSource);
      if (!passesSoftCaps(mode, path.etaMin, scenario.constraints)) {
        continue;
      }
      const opt: EvaluatedOption = new EvaluatedOption();
      opt.meetingPoint = cand.point;
      opt.routeIndex = cand.routeIndex;
      opt.mode = mode;
      opt.driverEtaMin = cand.driverEtaMin;
      opt.passengerEtaMin = path.etaMin;
      opt.completionMin = Math.max(cand.driverEtaMin, path.etaMin);
      opt.score = scoreOption(cand.driverEtaMin, path.etaMin, mode, cfg);
      opt.passengerPolyline = copyPolyline(path.polyline);
      evaluated.push(opt);
    }
  }

  const ranked: EvaluatedOption[] = rankOptions(evaluated);
  const perMode: EvaluatedOption[] = bestPerMode(ranked);
  const winner: EvaluatedOption | undefined = decideSwitch(baselineDriverEtaMin, ranked, cfg);

  const suggestions: Suggestion[] = [];
  for (let i = 0; i < perMode.length; i++) {
    const opt: EvaluatedOption = perMode[i];
    const driverSavedMin: number = Math.max(0, baselineDriverEtaMin - opt.driverEtaMin);
    let isRec: boolean = false;
    if (winner !== undefined) {
      if (winner.mode === opt.mode && winner.routeIndex === opt.routeIndex &&
        Math.abs(winner.score - opt.score) < 1e-9) {
        isRec = true;
      }
    }
    const s: Suggestion = new Suggestion();
    s.mode = opt.mode;
    s.recommended = isRec;
    s.meetingPoint = asNamed(opt.meetingPoint, `会合点·${modeLabelZh(opt.mode)}`, '');
    s.driverEtaMin = opt.driverEtaMin;
    s.passengerEtaMin = opt.passengerEtaMin;
    s.completionMin = opt.completionMin;
    s.driverSavedMin = driverSavedMin;
    s.score = opt.score;
    s.rationale = buildMoveRationale(opt.mode, opt.driverEtaMin, opt.passengerEtaMin, driverSavedMin);
    s.driverRoutePolyline = sliceDriverPolyline(fullPolyline, opt.routeIndex);
    s.passengerPathPolyline = copyPolyline(opt.passengerPolyline);
    suggestions.push(s);
  }

  const recommendStay: boolean = winner === undefined;
  if (recommendStay) {
    for (let i = 0; i < suggestions.length; i++) {
      suggestions[i].recommended = false;
    }
  } else {
    let found: boolean = false;
    for (let i = 0; i < suggestions.length; i++) {
      if (suggestions[i].recommended) {
        if (found) {
          suggestions[i].recommended = false;
        } else {
          found = true;
        }
      }
    }
    if (!found && suggestions.length > 0) {
      let idx: number = 0;
      if (winner !== undefined) {
        for (let i = 0; i < suggestions.length; i++) {
          if (suggestions[i].mode === winner.mode) {
            idx = i;
            break;
          }
        }
      }
      suggestions[idx].recommended = true;
    }
  }

  const stayPut: StayPutSuggestion = new StayPutSuggestion();
  stayPut.recommended = recommendStay;
  stayPut.driverEtaMin = baselineDriverEtaMin;
  stayPut.completionMin = baselineDriverEtaMin;
  const stayName: string = passenger.name.length > 0 ? passenger.name : '乘客位置';
  stayPut.meetingPoint = asNamed(passengerGeo, stayName, passenger.address);
  stayPut.rationale = templateStayRationale(baselineDriverEtaMin);
  stayPut.driverRoutePolyline = fullPolyline.length > 0 ? fullPolyline : [driverGeo, passengerGeo];

  result.dataSource = dataSource;
  result.stayPut = stayPut;
  result.suggestions = suggestions;
  return result;
}

export class EstimateProviders implements AnalysisProviders {
  async getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> {
    const built: StraightRouteBuild = buildStraightDrivingRoute(from, to);
    const out: DrivingRouteResult = new DrivingRouteResult();
    out.polyline = built.polyline;
    out.route = built.route;
    out.dataSource = DATA_ESTIMATE;
    return out;
  }

  async getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    _city: string
  ): Promise<PassengerPathResult> {
    const path: PassengerPathEstimate = estimatePassengerPath(mode, from, to);
    const out: PassengerPathResult = new PassengerPathResult();
    out.etaMin = path.etaMin;
    out.polyline = path.polyline;
    out.dataSource = DATA_ESTIMATE;
    return out;
  }
}

export async function runEstimateAnalysis(
  scenario: Scenario,
  cfg: EngineConfig = defaultEngineConfig(),
  generatedAt: string = new Date().toISOString()
): Promise<RecommendationSet> {
  return runAnalysis(scenario, new EstimateProviders(), cfg, generatedAt);
}
