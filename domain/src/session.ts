/**
 * TripSession state machine helpers (pure).
 * planning → confirmed → closed. Confirm freezes selection; re-plan closes old.
 */

import type {
  NamedPoint,
  RecommendationSet,
  SelectedPlan,
  SessionStatus,
  StayPutSuggestion,
  Suggestion,
  TripSession,
  Scenario,
} from './models.ts';
import { resolveGroundedSelection, stayPutPlanId, suggestionPlanId } from './agent/grounding.ts';
import { haversineM } from './geo.ts';

export interface LockedPlanSnapshot {
  readonly planId: string;
  readonly kind: 'stayPut' | 'suggestion';
  readonly modeLabel: string;
  readonly modeKey: string;
  readonly meetingPoint: NamedPoint;
  readonly driverEtaMin: number;
  readonly passengerEtaMin: number;
  readonly completionMin: number;
  readonly driverSavedMin: number;
  readonly rationale: string;
  readonly driverRoutePolyline: readonly { readonly lon: number; readonly lat: number }[];
  readonly passengerPathPolyline: readonly { readonly lon: number; readonly lat: number }[];
  readonly dataSource: string;
  readonly recommended: boolean;
}

function newSessionId(nowIso: string): string {
  const stamp = nowIso.replace(/[^0-9]/g, '').slice(0, 14);
  const rnd = Math.floor(Math.random() * 9000 + 1000);
  return `trip-${stamp || '0'}-${rnd}`;
}

export function planIdFromSelected(selected: SelectedPlan): string {
  if (selected.kind === 'stayPut') {
    return stayPutPlanId();
  }
  return suggestionPlanId(selected.index);
}

export function selectedFromPlanId(planId: string): SelectedPlan {
  const grounded = planId.trim();
  if (grounded === stayPutPlanId() || grounded.length === 0) {
    return { kind: 'stayPut' };
  }
  if (grounded.startsWith('suggestion:')) {
    const idx = Number(grounded.slice('suggestion:'.length));
    if (!Number.isNaN(idx) && idx >= 0) {
      return { kind: 'suggestion', index: Math.floor(idx) };
    }
  }
  return { kind: 'stayPut' };
}

export function createPlanningSession(
  scenario: Scenario,
  recommendationSet: RecommendationSet,
  planId: string = '',
  nowIso: string = new Date().toISOString(),
): TripSession {
  const resolved = resolveGroundedSelection(planId, recommendationSet);
  return {
    id: newSessionId(nowIso),
    status: 'planning',
    scenario,
    recommendationSet,
    selected: selectedFromPlanId(resolved),
  };
}

/**
 * Confirm freezes the selected plan on a copy. Does not mutate the input.
 * Only planning sessions can be confirmed; otherwise returns the same status.
 */
export function confirmSession(
  session: TripSession,
  planId: string = '',
  lockedAt: string = new Date().toISOString(),
  meetingLabelOverride?: NamedPoint,
): TripSession {
  if (session.status !== 'planning') {
    return session;
  }
  const resolved = resolveGroundedSelection(planId || planIdFromSelected(session.selected), session.recommendationSet);
  const selected = selectedFromPlanId(resolved);
  let recommendationSet = session.recommendationSet;

  if (meetingLabelOverride) {
    recommendationSet = applyMeetingLabel(recommendationSet, selected, meetingLabelOverride);
  }

  return {
    id: session.id,
    status: 'confirmed',
    scenario: session.scenario,
    recommendationSet,
    selected,
    lockedAt,
  };
}

/**
 * Close (archive) a session. Re-plan should close the old confirmed session
 * and create a new planning attempt — never mutate a locked snapshot in place.
 */
export function closeSession(session: TripSession): TripSession {
  if (session.status === 'closed') {
    return session;
  }
  return {
    id: session.id,
    status: 'closed',
    scenario: session.scenario,
    recommendationSet: session.recommendationSet,
    selected: session.selected,
    lockedAt: session.lockedAt,
  };
}

export function isTerminalStatus(status: SessionStatus): boolean {
  return status === 'closed';
}

export function isLockedStatus(status: SessionStatus): boolean {
  return status === 'confirmed';
}

function applyMeetingLabel(
  rec: RecommendationSet,
  selected: SelectedPlan,
  label: NamedPoint,
): RecommendationSet {
  if (selected.kind === 'stayPut') {
    const stay: StayPutSuggestion = {
      ...rec.stayPut,
      meetingPoint: {
        lon: rec.stayPut.meetingPoint.lon,
        lat: rec.stayPut.meetingPoint.lat,
        name: label.name ?? rec.stayPut.meetingPoint.name,
        address: label.address ?? rec.stayPut.meetingPoint.address,
      },
    };
    return { ...rec, stayPut: stay };
  }
  const idx = selected.index;
  if (idx < 0 || idx >= rec.suggestions.length) {
    return rec;
  }
  const next: Suggestion[] = rec.suggestions.map((s, i) => {
    if (i !== idx) return s;
    return {
      ...s,
      meetingPoint: {
        lon: s.meetingPoint.lon,
        lat: s.meetingPoint.lat,
        name: label.name ?? s.meetingPoint.name,
        address: label.address ?? s.meetingPoint.address,
      },
    };
  });
  return { ...rec, suggestions: next };
}

export function resolveLockedPlan(session: TripSession): LockedPlanSnapshot {
  const planId = resolveGroundedSelection(planIdFromSelected(session.selected), session.recommendationSet);
  const rec = session.recommendationSet;
  if (planId === stayPutPlanId()) {
    const stay = rec.stayPut;
    return {
      planId,
      kind: 'stayPut',
      modeLabel: '原地等待',
      modeKey: 'stay',
      meetingPoint: stay.meetingPoint,
      driverEtaMin: stay.driverEtaMin,
      passengerEtaMin: 0,
      completionMin: stay.completionMin,
      driverSavedMin: 0,
      rationale: stay.rationale,
      driverRoutePolyline: stay.driverRoutePolyline,
      passengerPathPolyline: [],
      dataSource: rec.dataSource,
      recommended: stay.recommended,
    };
  }
  const idx = Number(planId.slice('suggestion:'.length));
  const s = rec.suggestions[idx];
  if (!s) {
    return resolveLockedPlan({
      ...session,
      selected: { kind: 'stayPut' },
    });
  }
  return {
    planId,
    kind: 'suggestion',
    modeLabel: modeZh(s.mode),
    modeKey: s.mode,
    meetingPoint: s.meetingPoint,
    driverEtaMin: s.driverEtaMin,
    passengerEtaMin: s.passengerEtaMin,
    completionMin: s.completionMin,
    driverSavedMin: s.driverSavedMin,
    rationale: s.rationale,
    driverRoutePolyline: s.driverRoutePolyline,
    passengerPathPolyline: s.passengerPathPolyline,
    dataSource: rec.dataSource,
    recommended: s.recommended,
  };
}

function modeZh(mode: string): string {
  if (mode === 'walking') return '步行';
  if (mode === 'bicycle') return '骑行';
  if (mode === 'transit') return '公交';
  return mode;
}

/**
 * POI snap policy (name only):
 * - Never invent or move coordinates.
 * - Accept a POI name only if haversine distance ≤ poiSnapRadiusM (default 80 m).
 * - Estimate providers return empty POI lists → label stays reverse-geocode / coord text.
 */
export const DEFAULT_POI_SNAP_RADIUS_M = 80;

export function shouldAcceptPoiName(
  meetingLon: number,
  meetingLat: number,
  poiLon: number,
  poiLat: number,
  radiusM: number = DEFAULT_POI_SNAP_RADIUS_M,
): boolean {
  const distanceM = haversineM(
    { lon: meetingLon, lat: meetingLat },
    { lon: poiLon, lat: poiLat },
  );
  return distanceM <= radiusM;
}
