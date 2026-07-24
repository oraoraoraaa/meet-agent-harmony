/**
 * TripSession state machine — ArkTS port of domain/src/session.ts.
 * planning → confirmed → closed. Confirm freezes selection; re-plan closes old.
 */

import {
  dataSourceLabelZh,
  GeoPoint,
  modeLabelZh,
  NamedPoint,
  RecommendationSet,
  SelectedPlan,
  SESSION_CLOSED,
  SESSION_CONFIRMED,
  SESSION_PLANNING,
  SessionStatus,
  StayPutSuggestion,
  Suggestion,
  TripSession,
  Scenario
} from '../../domain/Models';
import { resolveGroundedSelection, stayPutPlanId, suggestionPlanId } from '../agent/Grounding';
import { haversineM } from '../../domain/Geo';

/** Name-only POI snap radius (meters). Never moves coordinates. */
export const DEFAULT_POI_SNAP_RADIUS_M: number = 80;

export class LockedPlanSnapshot {
  planId: string = '';
  kind: string = 'stayPut'; // stayPut | suggestion
  modeLabel: string = '';
  modeKey: string = '';
  meetingPoint: NamedPoint = new NamedPoint();
  driverEtaMin: number = 0;
  passengerEtaMin: number = 0;
  completionMin: number = 0;
  driverSavedMin: number = 0;
  rationale: string = '';
  driverRoutePolyline: GeoPoint[] = [];
  passengerPathPolyline: GeoPoint[] = [];
  dataSource: string = 'estimate';
  recommended: boolean = false;
}

function newSessionId(nowIso: string): string {
  let stamp: string = '';
  for (let i = 0; i < nowIso.length; i++) {
    const ch: string = nowIso.charAt(i);
    if (ch >= '0' && ch <= '9') {
      stamp += ch;
    }
  }
  if (stamp.length > 14) {
    stamp = stamp.substring(0, 14);
  }
  if (stamp.length === 0) {
    stamp = '0';
  }
  const rnd: number = Math.floor(Math.random() * 9000 + 1000);
  return `trip-${stamp}-${rnd}`;
}

export function planIdFromSelected(selected: SelectedPlan): string {
  if (selected.kind === 'stayPut') {
    return stayPutPlanId();
  }
  return suggestionPlanId(selected.index);
}

export function selectedFromPlanId(planId: string): SelectedPlan {
  const grounded: string = planId.trim();
  const out: SelectedPlan = new SelectedPlan();
  if (grounded === stayPutPlanId() || grounded.length === 0) {
    out.kind = 'stayPut';
    out.index = 0;
    return out;
  }
  if (grounded.indexOf('suggestion:') === 0) {
    const idx: number = Number(grounded.substring('suggestion:'.length));
    if (!isNaN(idx) && idx >= 0) {
      out.kind = 'suggestion';
      out.index = Math.floor(idx);
      return out;
    }
  }
  out.kind = 'stayPut';
  out.index = 0;
  return out;
}

function cloneNamed(p: NamedPoint): NamedPoint {
  return new NamedPoint(p.lon, p.lat, p.name, p.address);
}

function cloneGeoList(list: GeoPoint[]): GeoPoint[] {
  const out: GeoPoint[] = [];
  for (let i = 0; i < list.length; i++) {
    out.push(new GeoPoint(list[i].lon, list[i].lat));
  }
  return out;
}

function cloneStay(s: StayPutSuggestion): StayPutSuggestion {
  const out: StayPutSuggestion = new StayPutSuggestion();
  out.recommended = s.recommended;
  out.driverEtaMin = s.driverEtaMin;
  out.completionMin = s.completionMin;
  out.meetingPoint = cloneNamed(s.meetingPoint);
  out.rationale = s.rationale;
  out.driverRoutePolyline = cloneGeoList(s.driverRoutePolyline);
  return out;
}

function cloneSuggestion(s: Suggestion): Suggestion {
  const out: Suggestion = new Suggestion();
  out.mode = s.mode;
  out.recommended = s.recommended;
  out.meetingPoint = cloneNamed(s.meetingPoint);
  out.driverEtaMin = s.driverEtaMin;
  out.passengerEtaMin = s.passengerEtaMin;
  out.completionMin = s.completionMin;
  out.driverSavedMin = s.driverSavedMin;
  out.score = s.score;
  out.rationale = s.rationale;
  out.driverRoutePolyline = cloneGeoList(s.driverRoutePolyline);
  out.passengerPathPolyline = cloneGeoList(s.passengerPathPolyline);
  return out;
}

export function cloneRecommendationSet(rec: RecommendationSet): RecommendationSet {
  const out: RecommendationSet = new RecommendationSet();
  out.generatedAt = rec.generatedAt;
  out.dataSource = rec.dataSource;
  out.passengerStart = cloneNamed(rec.passengerStart);
  out.driverStart = cloneNamed(rec.driverStart);
  out.stayPut = cloneStay(rec.stayPut);
  const suggestions: Suggestion[] = [];
  for (let i = 0; i < rec.suggestions.length; i++) {
    suggestions.push(cloneSuggestion(rec.suggestions[i]));
  }
  out.suggestions = suggestions;
  return out;
}

function cloneScenario(s: Scenario): Scenario {
  const out: Scenario = new Scenario();
  out.city = s.city;
  out.driver = cloneNamed(s.driver);
  out.passenger = cloneNamed(s.passenger);
  out.constraints.allowedModes = s.constraints.allowedModes.slice();
  out.constraints.maxPassengerWalkMin = s.constraints.maxPassengerWalkMin;
  out.constraints.maxPassengerBikeMin = s.constraints.maxPassengerBikeMin;
  out.constraints.avoidTransit = s.constraints.avoidTransit;
  out.constraints.notes = s.constraints.notes;
  return out;
}

export function cloneTripSession(session: TripSession): TripSession {
  const out: TripSession = new TripSession();
  out.id = session.id;
  out.status = session.status;
  out.scenario = cloneScenario(session.scenario);
  out.recommendationSet = cloneRecommendationSet(session.recommendationSet);
  out.selected.kind = session.selected.kind;
  out.selected.index = session.selected.index;
  out.lockedAt = session.lockedAt;
  return out;
}

export function createPlanningSession(
  scenario: Scenario,
  recommendationSet: RecommendationSet,
  planId: string = '',
  nowIso: string = new Date().toISOString()
): TripSession {
  const resolved: string = resolveGroundedSelection(planId, recommendationSet);
  const session: TripSession = new TripSession();
  session.id = newSessionId(nowIso);
  session.status = SESSION_PLANNING;
  session.scenario = cloneScenario(scenario);
  session.recommendationSet = cloneRecommendationSet(recommendationSet);
  session.selected = selectedFromPlanId(resolved);
  session.lockedAt = '';
  return session;
}

function applyMeetingLabel(
  rec: RecommendationSet,
  selected: SelectedPlan,
  label: NamedPoint
): RecommendationSet {
  const next: RecommendationSet = cloneRecommendationSet(rec);
  if (selected.kind === 'stayPut') {
    next.stayPut.meetingPoint.name = label.name.length > 0 ? label.name : next.stayPut.meetingPoint.name;
    next.stayPut.meetingPoint.address =
      label.address.length > 0 ? label.address : next.stayPut.meetingPoint.address;
    // coords stay engine-owned
    return next;
  }
  const idx: number = selected.index;
  if (idx < 0 || idx >= next.suggestions.length) {
    return next;
  }
  const meet: NamedPoint = next.suggestions[idx].meetingPoint;
  meet.name = label.name.length > 0 ? label.name : meet.name;
  meet.address = label.address.length > 0 ? label.address : meet.address;
  return next;
}

/**
 * Confirm freezes the selected plan on a copy. Only planning sessions confirm.
 */
export function confirmSession(
  session: TripSession,
  planId: string = '',
  lockedAt: string = new Date().toISOString(),
  meetingLabelOverride: NamedPoint | null = null
): TripSession {
  if (session.status !== SESSION_PLANNING) {
    return cloneTripSession(session);
  }
  const pick: string = planId.length > 0 ? planId : planIdFromSelected(session.selected);
  const resolved: string = resolveGroundedSelection(pick, session.recommendationSet);
  const selected: SelectedPlan = selectedFromPlanId(resolved);
  let recommendationSet: RecommendationSet = cloneRecommendationSet(session.recommendationSet);
  if (meetingLabelOverride !== null) {
    recommendationSet = applyMeetingLabel(recommendationSet, selected, meetingLabelOverride);
  }
  const out: TripSession = new TripSession();
  out.id = session.id;
  out.status = SESSION_CONFIRMED;
  out.scenario = cloneScenario(session.scenario);
  out.recommendationSet = recommendationSet;
  out.selected = selected;
  out.lockedAt = lockedAt;
  return out;
}

export function closeSession(session: TripSession): TripSession {
  if (session.status === SESSION_CLOSED) {
    return cloneTripSession(session);
  }
  const out: TripSession = cloneTripSession(session);
  out.status = SESSION_CLOSED;
  return out;
}

export function isLockedStatus(status: SessionStatus): boolean {
  return status === SESSION_CONFIRMED;
}

export function resolveLockedPlan(session: TripSession): LockedPlanSnapshot {
  const planId: string = resolveGroundedSelection(
    planIdFromSelected(session.selected),
    session.recommendationSet
  );
  const rec: RecommendationSet = session.recommendationSet;
  const out: LockedPlanSnapshot = new LockedPlanSnapshot();
  out.planId = planId;
  out.dataSource = rec.dataSource;

  if (planId === stayPutPlanId()) {
    const stay: StayPutSuggestion = rec.stayPut;
    out.kind = 'stayPut';
    out.modeLabel = '原地等待';
    out.modeKey = 'stay';
    out.meetingPoint = cloneNamed(stay.meetingPoint);
    out.driverEtaMin = stay.driverEtaMin;
    out.passengerEtaMin = 0;
    out.completionMin = stay.completionMin;
    out.driverSavedMin = 0;
    out.rationale = stay.rationale;
    out.driverRoutePolyline = cloneGeoList(stay.driverRoutePolyline);
    out.passengerPathPolyline = [];
    out.recommended = stay.recommended;
    return out;
  }

  const idx: number = Number(planId.substring('suggestion:'.length));
  if (isNaN(idx) || idx < 0 || idx >= rec.suggestions.length) {
    const fallback: TripSession = cloneTripSession(session);
    fallback.selected.kind = 'stayPut';
    fallback.selected.index = 0;
    return resolveLockedPlan(fallback);
  }
  const s: Suggestion = rec.suggestions[idx];
  out.kind = 'suggestion';
  out.modeLabel = modeLabelZh(s.mode);
  out.modeKey = s.mode;
  out.meetingPoint = cloneNamed(s.meetingPoint);
  out.driverEtaMin = s.driverEtaMin;
  out.passengerEtaMin = s.passengerEtaMin;
  out.completionMin = s.completionMin;
  out.driverSavedMin = s.driverSavedMin;
  out.rationale = s.rationale;
  out.driverRoutePolyline = cloneGeoList(s.driverRoutePolyline);
  out.passengerPathPolyline = cloneGeoList(s.passengerPathPolyline);
  out.recommended = s.recommended;
  return out;
}

export function shouldAcceptPoiName(
  meetingLon: number,
  meetingLat: number,
  poiLon: number,
  poiLat: number,
  radiusM: number = DEFAULT_POI_SNAP_RADIUS_M
): boolean {
  const distanceM: number = haversineM(
    new GeoPoint(meetingLon, meetingLat),
    new GeoPoint(poiLon, poiLat)
  );
  return distanceM <= radiusM;
}

export function dataSourceLabelForSession(session: TripSession): string {
  return dataSourceLabelZh(session.recommendationSet.dataSource);
}
