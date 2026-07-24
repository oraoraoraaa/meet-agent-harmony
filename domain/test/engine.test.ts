import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bestPerMode,
  decideSwitch,
  rankOptions,
  reachableModes,
  scoreOption,
  type EvaluatedOption,
  type MobilityMode,
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
  // baseline 12; option score must be <= 10.5 with default minImprovement 1.5
  const strong = opt('walking', 8, 7, 5);
  // recompute realistic score
  const scored = {
    ...strong,
    score: scoreOption(7, 5, 'walking'),
  };
  assert.ok(decideSwitch(12, [scored]));

  const marginal = {
    ...opt('walking', 11.5, 11.5, 6),
    score: scoreOption(11.5, 6, 'walking'),
  };
  assert.equal(decideSwitch(12, [marginal]), null);
});
