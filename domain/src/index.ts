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

export type {
  AgentRole,
  ChatMessage,
  ToolCall,
  ToolDefinition,
  ToolTraceEntry,
  AgentTurnResult,
  AgentSessionSnapshot,
} from './agent/index.ts';

export {
  MEET_AGENT_SYSTEM_PROMPT,
  DEFAULT_MAX_TOOL_ITERS,
  DEFAULT_LLM_TEMPERATURE,
  TOOL_GET_SCENARIO_SNAPSHOT,
  TOOL_SET_CONSTRAINTS,
  TOOL_GET_DRIVING_ROUTE,
  TOOL_GENERATE_AND_SCORE,
  TOOL_REVERSE_GEOCODE,
  TOOL_SEARCH_POI_NEAR,
  TOOL_FORMAT_SHARE_TEXT,
  AGENT_TOOL_DEFINITIONS,
  openAiToolsPayload,
  stayPutPlanId,
  suggestionPlanId,
  parseSuggestionIndex,
  isGroundedPlanId,
  extractPlanIdFromText,
  resolveGroundedSelection,
  validateOrFallbackPlanId,
  buildOfflinePlanReply,
  formatShareText,
} from './agent/index.ts';

export { runOfflineAgentTurn, finalizeLlmTurn } from './agent/orchestrator.ts';
export type { EngineOnlyPlanFn } from './agent/orchestrator.ts';

export type { LockedPlanSnapshot } from './session.ts';
export {
  DEFAULT_POI_SNAP_RADIUS_M,
  planIdFromSelected,
  selectedFromPlanId,
  createPlanningSession,
  confirmSession,
  closeSession,
  isTerminalStatus,
  isLockedStatus,
  resolveLockedPlan,
  shouldAcceptPoiName,
} from './session.ts';
