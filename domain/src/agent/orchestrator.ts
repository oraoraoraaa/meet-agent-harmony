/**
 * Pure orchestration helpers (testable without HTTP).
 * Full tool loop with LLM lives in entry services; this file owns grounding + offline path.
 */

import type { RecommendationSet, Scenario } from '../models.ts';
import type { AgentTurnResult, ToolTraceEntry } from './types.ts';
import { buildOfflinePlanReply } from './offlineReply.ts';
import {
  extractPlanIdFromText,
  resolveGroundedSelection,
  validateOrFallbackPlanId,
} from './grounding.ts';

export interface EngineOnlyPlanFn {
  (scenario: Scenario): Promise<RecommendationSet> | RecommendationSet;
}

/**
 * Mode C path: run engine, template reply, grounded recommended id.
 */
export async function runOfflineAgentTurn(
  scenario: Scenario,
  planFn: EngineOnlyPlanFn,
  extraTrace: readonly ToolTraceEntry[] = [],
): Promise<AgentTurnResult> {
  const t0 = Date.now();
  let rec: RecommendationSet;
  try {
    rec = await planFn(scenario);
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'engine failed';
    return {
      replyText: `本地规划失败：${msg}。请检查起终点坐标后重试。`,
      recommendation: null,
      selectedPlanId: '',
      toolTrace: [
        ...extraTrace,
        {
          name: 'generate_and_score_plans',
          ok: false,
          durationMs: Date.now() - t0,
          summary: 'engine error',
          error: msg,
        },
      ],
      usedLlm: false,
      offlineFallback: true,
      error: msg,
    };
  }

  const durationMs = Date.now() - t0;
  const selectedPlanId = resolveGroundedSelection('', rec);
  const trace: ToolTraceEntry[] = [
    ...extraTrace,
    {
      name: 'generate_and_score_plans',
      ok: true,
      durationMs,
      summary: `options=${1 + rec.suggestions.length} dataSource=${rec.dataSource}`,
    },
  ];

  return {
    replyText: buildOfflinePlanReply(rec),
    recommendation: rec,
    selectedPlanId,
    toolTrace: trace,
    usedLlm: false,
    offlineFallback: true,
  };
}

/**
 * After LLM final text: ground plan id; if hallucinated, replace with engine recommendation.
 */
export function finalizeLlmTurn(
  replyText: string,
  rec: RecommendationSet | null,
  toolTrace: readonly ToolTraceEntry[],
  opts?: { readonly forceOfflineNote?: boolean },
): AgentTurnResult {
  const claimed = extractPlanIdFromText(replyText);
  const grounded = validateOrFallbackPlanId(claimed, rec);
  let text = replyText;
  if (grounded.rejectedHallucination) {
    text =
      replyText +
      `\n\n（系统校验：模型引用了无效方案 ID「${claimed}」，已回退到引擎推荐 ${grounded.planId}。）`;
  }
  if (opts?.forceOfflineNote && rec) {
    // keep prose; numbers already from rec when UI binds cards
  }
  return {
    replyText: text,
    recommendation: rec,
    selectedPlanId: grounded.planId,
    toolTrace,
    usedLlm: true,
    offlineFallback: false,
  };
}
