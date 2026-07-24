import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bestPerMode,
  buildStraightDrivingRoute,
  decideSwitch,
  generateRouteCandidates,
  haversineM,
  rankOptions,
  reachableModes,
  runEstimateAnalysis,
  scoreOption,
  type EvaluatedOption,
  type MobilityMode,
  type Scenario,
} from '../src/index.ts';

function opt(mode: MobilityMode, score: number, driver = score, passenger = 1): EvaluatedOption {
  return {
    meetingPoint: { lon: 0, lat: 0 },
    routeIndex: 0,
    mode,
    driverEtaMin: driver,
    passengerEtaMin: passenger,
    completionMin: Math.max(driver, passenger),
    score,
  };
}

test('reachableModes gates by distance', () => {
  assert.deepEqual(reachableModes(500), ['walking', 'bicycle']);
  assert.deepEqual(reachableModes(2500), ['bicycle', 'transit']);
  assert.deepEqual(reachableModes(6000), ['transit']);
  assert.deepEqual(reachableModes(10000), []);
});

test('scoreOption penalizes heavier modes', () => {
  const walk = scoreOption(10, 5, 'walking');
  const bike = scoreOption(10, 5, 'bicycle');
  const transit = scoreOption(10, 5, 'transit');
  assert.ok(walk < bike && bike < transit);
});

test('rankOptions sorts by score then passenger effort', () => {
  const ranked = rankOptions([
    opt('walking', 20, 18, 5),
    opt('walking', 11, 6, 9),
    opt('walking', 11, 10, 3),
    opt('walking', 9, 8, 4),
  ]);
  assert.equal(ranked[0].score, 9);
  assert.equal(ranked[1].passengerEtaMin, 3);
  assert.equal(ranked[2].passengerEtaMin, 9);
});

test('bestPerMode keeps first occurrence in rank order', () => {
  const winners = bestPerMode([
    opt('bicycle', 8),
    opt('walking', 9),
    opt('bicycle', 10),
    opt('transit', 11),
  ]);
  assert.equal(winners.length, 3);
  assert.equal(winners[0].mode, 'bicycle');
  assert.equal(winners[1].mode, 'walking');
  assert.equal(winners[2].mode, 'transit');
});

test('decideSwitch respects improvement margin', () => {
  const scored = {
    ...opt('walking', 8, 7, 5),
    score: scoreOption(7, 5, 'walking'),
  };
  assert.ok(decideSwitch(12, [scored]));

  const marginal = {
    ...opt('walking', 11.5, 11.5, 6),
    score: scoreOption(11.5, 6, 'walking'),
  };
  assert.equal(decideSwitch(12, [marginal]), null);
});

test('haversineM is symmetric and zero for same point', () => {
  const a = { lon: 108.94, lat: 34.26 };
  const b = { lon: 108.95, lat: 34.27 };
  assert.equal(haversineM(a, a), 0);
  assert.ok(Math.abs(haversineM(a, b) - haversineM(b, a)) < 1e-6);
  assert.ok(haversineM(a, b) > 1000 && haversineM(a, b) < 2000);
});

test('generateRouteCandidates enforces spacing and max count', () => {
  const from = { lon: 108.89, lat: 34.23 };
  const to = { lon: 108.95, lat: 34.26 };
  const { route } = buildStraightDrivingRoute(from, to, { segmentM: 80 });
  const passenger = to;
  const candidates = generateRouteCandidates(route, passenger, {
    maxCandidates: 4,
    minCandidateSpacingM: 250,
    minPassengerMoveM: 120,
    walkReachM: 1200,
    bicycleReachM: 3500,
    transitReachM: 8000,
    transitMinM: 2000,
    minDriverSavingSecs: 60,
    passengerBurdenWeight: 0.15,
    bicyclePenaltyMin: 1,
    transitPenaltyMin: 2.5,
    minImprovementMin: 1.5,
  });
  assert.ok(candidates.length > 0);
  assert.ok(candidates.length <= 4);
  for (const c of candidates) {
    assert.ok(c.passengerStraightM >= 120);
    assert.ok(c.driverEtaMin >= 0);
  }
  // Spacing along route indices should not collapse to one point only if long route
  if (candidates.length >= 2) {
    assert.ok(candidates[candidates.length - 1]!.routeIndex > candidates[0]!.routeIndex);
  }
});

test('xian fixture estimate analysis produces stable multi-option set', async () => {
  const scenario: Scenario = {
    driver: { name: '高新', lon: 108.8905, lat: 34.2324 },
    passenger: { name: '钟楼', lon: 108.9465, lat: 34.261 },
    city: '西安',
    constraints: {
      allowedModes: ['walking', 'bicycle', 'transit'],
      maxPassengerWalkMin: 12,
      avoidTransit: false,
    },
  };

  const result = await runEstimateAnalysis(scenario, {
    now: () => new Date('2026-07-24T12:00:00.000Z'),
  });

  assert.equal(result.dataSource, 'estimate');
  assert.equal(result.generatedAt, '2026-07-24T12:00:00.000Z');
  assert.ok(result.stayPut.driverEtaMin > 5);
  assert.ok(result.stayPut.driverRoutePolyline.length >= 2);

  const recommendedFlags =
    (result.stayPut.recommended ? 1 : 0) + result.suggestions.filter((s) => s.recommended).length;
  assert.equal(recommendedFlags, 1, 'exactly one recommended option');

  // At least stay-put always present; suggestions depend on reach
  for (const s of result.suggestions) {
    assert.ok(s.driverRoutePolyline.length >= 1);
    assert.ok(s.passengerPathPolyline.length >= 2);
    assert.ok(s.passengerEtaMin > 0);
    assert.ok(s.score > 0);
  }

  // Re-run is deterministic for scores/modes
  const again = await runEstimateAnalysis(scenario, {
    now: () => new Date('2026-07-24T12:00:00.000Z'),
  });
  assert.equal(again.suggestions.length, result.suggestions.length);
  assert.equal(again.stayPut.recommended, result.stayPut.recommended);
  if (result.suggestions[0]) {
    assert.equal(again.suggestions[0]!.mode, result.suggestions[0]!.mode);
    assert.ok(Math.abs(again.suggestions[0]!.score - result.suggestions[0]!.score) < 1e-9);
  }
});

test('avoidTransit filters transit suggestions', async () => {
  const scenario: Scenario = {
    driver: { lon: 108.89, lat: 34.23 },
    passenger: { lon: 108.95, lat: 34.26 },
    constraints: {
      allowedModes: ['walking', 'bicycle', 'transit'],
      avoidTransit: true,
    },
  };
  const result = await runEstimateAnalysis(scenario);
  assert.ok(result.suggestions.every((s) => s.mode !== 'transit'));
});
