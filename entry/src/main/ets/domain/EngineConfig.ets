/**
 * Engine knobs — mirror domain/src/engineConfig.ts
 */

export class EngineConfig {
  maxCandidates: number = 4;
  minCandidateSpacingM: number = 250;
  minPassengerMoveM: number = 120;
  walkReachM: number = 1200;
  bicycleReachM: number = 3500;
  transitReachM: number = 8000;
  transitMinM: number = 2000;
  minDriverSavingSecs: number = 60;
  passengerBurdenWeight: number = 0.15;
  bicyclePenaltyMin: number = 1.0;
  transitPenaltyMin: number = 2.5;
  minImprovementMin: number = 1.5;
}

export function defaultEngineConfig(): EngineConfig {
  return new EngineConfig();
}
