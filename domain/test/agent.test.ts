import assert from 'node:assert/strict';
import test from 'node:test';

import {
  extractPlanIdFromText,
  isGroundedPlanId,
  resolveGroundedSelection,
  runOfflineAgentTurn,
  stayPutPlanId,
  suggestionPlanId,
  validateOrFallbackPlanId,
  type RecommendationSet,
  type Scenario,
} from '../src/index.ts';
import { runEstimateAnalysis } from '../src/index.ts';

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

test('isGroundedPlanId accepts stayPut and valid suggestion indices', async () => {
  const rec = await runEstimateAnalysis(xianScenario());
  assert.equal(isGroundedPlanId('stayPut', rec), true);
  assert.equal(isGroundedPlanId('suggestion:0', rec), rec.suggestions.length > 0);
  assert.equal(isGroundedPlanId('suggestion:999', rec), false);
  assert.equal(isGroundedPlanId('meeting-xyz', rec), false);
  assert.equal(isGroundedPlanId('stayPut', null), false);
});

test('validateOrFallbackPlanId rejects hallucinated candidate IDs', async () => {
  const rec = await runEstimateAnalysis(xianScenario());
  const bad = validateOrFallbackPlanId('suggestion:999', rec);
  assert.equal(bad.rejectedHallucination, true);
  assert.ok(isGroundedPlanId(bad.planId, rec));

  const okId = stayPutPlanId();
  const good = validateOrFallbackPlanId(okId, rec);
  assert.equal(good.rejectedHallucination, false);
  assert.equal(good.planId, okId);

  if (rec.suggestions.length > 0) {
    const sid = suggestionPlanId(0);
    const g2 = validateOrFallbackPlanId(sid, rec);
    assert.equal(g2.rejectedHallucination, false);
    assert.equal(g2.planId, sid);
  }
});

test('extractPlanIdFromText finds PLAN_ID marker and bare tokens', () => {
  assert.equal(extractPlanIdFromText('推荐 PLAN_ID:stayPut 即可'), 'stayPut');
  assert.equal(extractPlanIdFromText('选 suggestion:1 更合适'), 'suggestion:1');
  assert.equal(extractPlanIdFromText('没有 id'), '');
});

test('resolveGroundedSelection prefers engine recommended flag', () => {
  const rec: RecommendationSet = {
    generatedAt: 't',
    dataSource: 'estimate',
    passengerStart: { lon: 0, lat: 0 },
    driverStart: { lon: 1, lat: 1 },
    stayPut: {
      recommended: false,
      driverEtaMin: 20,
      completionMin: 20,
      meetingPoint: { lon: 0, lat: 0, name: 'P' },
      rationale: 'stay',
      driverRoutePolyline: [],
    },
    suggestions: [
      {
        mode: 'walking',
        recommended: true,
        meetingPoint: { lon: 0.5, lat: 0.5, name: 'M' },
        driverEtaMin: 12,
        passengerEtaMin: 8,
        completionMin: 12,
        driverSavedMin: 8,
        score: 10,
        rationale: 'walk',
        driverRoutePolyline: [],
        passengerPathPolyline: [],
      },
    ],
  };
  assert.equal(resolveGroundedSelection('', rec), 'suggestion:0');
  assert.equal(resolveGroundedSelection('stayPut', rec), 'stayPut');
});

test('runOfflineAgentTurn returns grounded multi-option reply without LLM', async () => {
  const turn = await runOfflineAgentTurn(xianScenario(), (s) => runEstimateAnalysis(s));
  assert.equal(turn.usedLlm, false);
  assert.equal(turn.offlineFallback, true);
  assert.ok(turn.recommendation);
  assert.ok(isGroundedPlanId(turn.selectedPlanId, turn.recommendation));
  assert.ok(turn.replyText.includes('本地引擎') || turn.replyText.includes('估算'));
  assert.ok(turn.toolTrace.some((t) => t.name === 'generate_and_score_plans' && t.ok));
});

test('constraint avoidTransit still grounds offline turn', async () => {
  const scenario: Scenario = {
    ...xianScenario(),
    constraints: {
      allowedModes: ['walking', 'bicycle'],
      avoidTransit: true,
      maxPassengerWalkMin: 12,
    },
  };
  const turn = await runOfflineAgentTurn(scenario, (s) => runEstimateAnalysis(s));
  assert.ok(turn.recommendation);
  for (const s of turn.recommendation!.suggestions) {
    assert.notEqual(s.mode, 'transit');
  }
});
