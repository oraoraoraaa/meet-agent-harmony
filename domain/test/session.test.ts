import assert from 'node:assert/strict';
import test from 'node:test';

import {
  closeSession,
  confirmSession,
  createPlanningSession,
  planIdFromSelected,
  resolveLockedPlan,
  runEstimateAnalysis,
  shouldAcceptPoiName,
  stayPutPlanId,
  type Scenario,
} from '../src/index.ts';

function xianScenario(): Scenario {
  return {
    driver: { lon: 108.8905, lat: 34.2324, name: '高新' },
    passenger: { lon: 108.9465, lat: 34.2610, name: '钟楼' },
    city: '西安',
    constraints: {
      allowedModes: ['walking', 'bicycle', 'transit'],
      maxPassengerWalkMin: 12,
    },
  };
}

test('TripSession planning → confirmed freezes selected plan', async () => {
  const rec = await runEstimateAnalysis(xianScenario());
  const planning = createPlanningSession(xianScenario(), rec, '', '2026-07-25T10:00:00.000Z');
  assert.equal(planning.status, 'planning');
  assert.ok(planning.id.startsWith('trip-'));

  const confirmed = confirmSession(planning, stayPutPlanId(), '2026-07-25T10:01:00.000Z');
  assert.equal(confirmed.status, 'confirmed');
  assert.equal(confirmed.lockedAt, '2026-07-25T10:01:00.000Z');
  assert.equal(planIdFromSelected(confirmed.selected), 'stayPut');
  assert.equal(planning.status, 'planning'); // original not mutated

  const locked = resolveLockedPlan(confirmed);
  assert.equal(locked.kind, 'stayPut');
  assert.equal(locked.driverEtaMin, rec.stayPut.driverEtaMin);
  assert.ok(locked.rationale.length > 0);
});

test('confirmSession does not re-lock an already confirmed session', async () => {
  const rec = await runEstimateAnalysis(xianScenario());
  const planning = createPlanningSession(xianScenario(), rec);
  const confirmed = confirmSession(planning, stayPutPlanId(), 't1');
  const again = confirmSession(confirmed, 'suggestion:0', 't2');
  assert.equal(again.status, 'confirmed');
  assert.equal(again.lockedAt, 't1');
  assert.equal(planIdFromSelected(again.selected), 'stayPut');
});

test('re-plan closes old session without mutating snapshot fields', async () => {
  const rec = await runEstimateAnalysis(xianScenario());
  const planning = createPlanningSession(xianScenario(), rec, stayPutPlanId());
  const confirmed = confirmSession(planning, stayPutPlanId(), 't1');
  const closed = closeSession(confirmed);
  assert.equal(closed.status, 'closed');
  assert.equal(closed.id, confirmed.id);
  assert.equal(closed.recommendationSet.stayPut.driverEtaMin, confirmed.recommendationSet.stayPut.driverEtaMin);
  assert.equal(confirmed.status, 'confirmed');
});

test('confirm can attach meeting label without moving coordinates', async () => {
  const rec = await runEstimateAnalysis(xianScenario());
  const planning = createPlanningSession(xianScenario(), rec, stayPutPlanId());
  const lon = rec.stayPut.meetingPoint.lon;
  const lat = rec.stayPut.meetingPoint.lat;
  const confirmed = confirmSession(planning, stayPutPlanId(), 't1', {
    lon,
    lat,
    name: '钟楼路口',
    address: '估算标签',
  });
  const locked = resolveLockedPlan(confirmed);
  assert.equal(locked.meetingPoint.lon, lon);
  assert.equal(locked.meetingPoint.lat, lat);
  assert.equal(locked.meetingPoint.name, '钟楼路口');
});

test('POI snap radius accepts near names only', () => {
  // ~0 m
  assert.equal(shouldAcceptPoiName(108.9, 34.2, 108.9, 34.2, 80), true);
  // roughly > 1 km
  assert.equal(shouldAcceptPoiName(108.9, 34.2, 108.92, 34.2, 80), false);
});
