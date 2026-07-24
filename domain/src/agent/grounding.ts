/**
 * Grounding: final plan IDs must exist in the last RecommendationSet.
 */

import type { RecommendationSet } from '../models.ts';

export function stayPutPlanId(): string {
  return 'stayPut';
}

export function suggestionPlanId(index: number): string {
  return `suggestion:${index}`;
}

export function parseSuggestionIndex(planId: string): number | null {
  if (!planId.startsWith('suggestion:')) {
    return null;
  }
  const raw = planId.slice('suggestion:'.length);
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0) {
    return null;
  }
  return n;
}

/** True if planId is stayPut or a valid suggestion index in rec. */
export function isGroundedPlanId(planId: string, rec: RecommendationSet | null | undefined): boolean {
  if (!planId || !rec) {
    return false;
  }
  if (planId === stayPutPlanId()) {
    return true;
  }
  const idx = parseSuggestionIndex(planId);
  if (idx === null) {
    return false;
  }
  return idx >= 0 && idx < rec.suggestions.length;
}

/**
 * Extract a plan id mentioned by the model (or structured marker).
 * Accepts:
 * - PLAN_ID:stayPut
 * - PLAN_ID:suggestion:0
 * - bare stayPut / suggestion:N tokens
 */
export function extractPlanIdFromText(text: string): string {
  const marker = text.match(/PLAN_ID\s*:\s*(stayPut|suggestion:\d+)/i);
  if (marker) {
    return marker[1];
  }
  const bare = text.match(/\b(stayPut|suggestion:\d+)\b/);
  if (bare) {
    return bare[1];
  }
  return '';
}

/**
 * Prefer explicit grounded id; else fall back to engine recommended option.
 */
export function resolveGroundedSelection(
  candidateId: string,
  rec: RecommendationSet | null | undefined,
): string {
  if (isGroundedPlanId(candidateId, rec)) {
    return candidateId;
  }
  if (!rec) {
    return '';
  }
  if (rec.stayPut.recommended) {
    return stayPutPlanId();
  }
  for (let i = 0; i < rec.suggestions.length; i++) {
    if (rec.suggestions[i].recommended) {
      return suggestionPlanId(i);
    }
  }
  return stayPutPlanId();
}

/** Reject hallucinated IDs: returns grounded id or engine fallback; never invents unknown. */
export function validateOrFallbackPlanId(
  modelClaimedId: string,
  rec: RecommendationSet | null | undefined,
): { readonly planId: string; readonly rejectedHallucination: boolean } {
  if (!modelClaimedId) {
    return { planId: resolveGroundedSelection('', rec), rejectedHallucination: false };
  }
  if (isGroundedPlanId(modelClaimedId, rec)) {
    return { planId: modelClaimedId, rejectedHallucination: false };
  }
  return {
    planId: resolveGroundedSelection('', rec),
    rejectedHallucination: true,
  };
}
