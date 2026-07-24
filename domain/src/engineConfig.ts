/**
 * Default engine knobs. Keep a single source of constants.
 */
export interface EngineConfig {
  readonly maxCandidates: number;
  readonly minCandidateSpacingM: number;
  readonly minPassengerMoveM: number;
  readonly walkReachM: number;
  readonly bicycleReachM: number;
  readonly transitReachM: number;
  readonly transitMinM: number;
  readonly minDriverSavingSecs: number;
  readonly passengerBurdenWeight: number;
  readonly bicyclePenaltyMin: number;
  readonly transitPenaltyMin: number;
  /** Winner must beat stay-put baseline by this many minutes. */
  readonly minImprovementMin: number;
}

export const DEFAULT_ENGINE_CONFIG: EngineConfig = {
  maxCandidates: 4,
  minCandidateSpacingM: 250,
  minPassengerMoveM: 120,
  walkReachM: 1200,
  bicycleReachM: 3500,
  transitReachM: 8000,
  transitMinM: 2000,
  minDriverSavingSecs: 60,
  passengerBurdenWeight: 0.15,
  bicyclePenaltyMin: 1.0,
  transitPenaltyMin: 2.5,
  minImprovementMin: 1.5,
};
