/**
 * Grounding helpers — ArkTS mirror of domain/src/agent/grounding.ts.
 */

import { RecommendationSet } from '../../domain/Models';

export function stayPutPlanId(): string {
  return 'stayPut';
}

export function suggestionPlanId(index: number): string {
  return `suggestion:${index}`;
}

export function parseSuggestionIndex(planId: string): number {
  if (!planId.startsWith('suggestion:')) {
    return -1;
  }
  const raw: string = planId.substring('suggestion:'.length);
  const n: number = Number(raw);
  if (isNaN(n) || n < 0 || Math.floor(n) !== n) {
    return -1;
  }
  return n;
}

export function isGroundedPlanId(planId: string, rec: RecommendationSet | null): boolean {
  if (planId.length === 0 || rec === null) {
    return false;
  }
  if (planId === stayPutPlanId()) {
    return true;
  }
  const idx: number = parseSuggestionIndex(planId);
  if (idx < 0) {
    return false;
  }
  return idx < rec.suggestions.length;
}

export function extractPlanIdFromText(text: string): string {
  // Avoid RegExpMatchArray typing issues on ArkTS — manual scan.
  const upperMarker: string = 'PLAN_ID:';
  const lowerMarker: string = 'plan_id:';
  let idx: number = text.indexOf(upperMarker);
  if (idx < 0) {
    idx = text.toLowerCase().indexOf(lowerMarker);
    if (idx >= 0) {
      // map lower index onto original string carefully
      const tail: string = text.substring(idx + lowerMarker.length).trim();
      return readPlanToken(tail);
    }
  } else {
    const tail: string = text.substring(idx + upperMarker.length).trim();
    return readPlanToken(tail);
  }
  const stayIdx: number = text.indexOf('stayPut');
  if (stayIdx >= 0) {
    return 'stayPut';
  }
  const sugIdx: number = text.indexOf('suggestion:');
  if (sugIdx >= 0) {
    return readPlanToken(text.substring(sugIdx));
  }
  return '';
}

function readPlanToken(tail: string): string {
  if (tail.startsWith('stayPut')) {
    return 'stayPut';
  }
  if (tail.startsWith('suggestion:')) {
    let i: number = 'suggestion:'.length;
    let digits: string = '';
    while (i < tail.length) {
      const ch: string = tail.charAt(i);
      if (ch >= '0' && ch <= '9') {
        digits += ch;
        i++;
      } else {
        break;
      }
    }
    if (digits.length > 0) {
      return `suggestion:${digits}`;
    }
  }
  return '';
}

export function resolveGroundedSelection(candidateId: string, rec: RecommendationSet | null): string {
  if (isGroundedPlanId(candidateId, rec)) {
    return candidateId;
  }
  if (rec === null) {
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

export class GroundingResult {
  planId: string = '';
  rejectedHallucination: boolean = false;
}

export function validateOrFallbackPlanId(modelClaimedId: string, rec: RecommendationSet | null): GroundingResult {
  const out: GroundingResult = new GroundingResult();
  if (modelClaimedId.length === 0) {
    out.planId = resolveGroundedSelection('', rec);
    out.rejectedHallucination = false;
    return out;
  }
  if (isGroundedPlanId(modelClaimedId, rec)) {
    out.planId = modelClaimedId;
    out.rejectedHallucination = false;
    return out;
  }
  out.planId = resolveGroundedSelection('', rec);
  out.rejectedHallucination = true;
  return out;
}
