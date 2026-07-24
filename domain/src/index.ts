export type {
  MobilityMode,
  DataSource,
  GeoPoint,
  NamedPoint,
  Constraints,
  Scenario,
  RoutePoint,
  Candidate,
  EvaluatedOption,
  Suggestion,
  StayPutSuggestion,
  RecommendationSet,
  SessionStatus,
  SelectedPlan,
  TripSession,
} from './models.ts';

export type { EngineConfig } from './engineConfig.ts';
export { DEFAULT_ENGINE_CONFIG } from './engineConfig.ts';

export { haversineM } from './geo.ts';

export {
  modePenaltyMin,
  scoreOption,
  reachableModes,
  generateRouteCandidates,
  rankOptions,
  bestPerMode,
  decideSwitch,
  allowedModesFromConstraints,
  passesSoftCaps,
  sliceDriverPolyline,
} from './engine.ts';

export {
  EST_DRIVE_KMH,
  EST_WALK_KMH,
  EST_BIKE_KMH,
  EST_TRANSIT_KMH,
  speedKmhForMode,
  etaMinFromDistanceM,
  interpolatePoints,
  buildStraightDrivingRoute,
  estimatePassengerPath,
} from './estimate.ts';

export type {
  DrivingRouteResult,
  PassengerPathResult,
  AnalysisProviders,
  AnalysisOptions,
} from './runAnalysis.ts';
export { runAnalysis, runEstimateAnalysis } from './runAnalysis.ts';
