/**
 * In-memory TripSession store (process-lifetime).
 * Active planning + optional locked confirmed session for LockedSessionPage.
 */

import {
  NamedPoint,
  RecommendationSet,
  Scenario,
  SESSION_CONFIRMED,
  TripSession
} from '../../domain/Models';
import {
  cloneTripSession,
  closeSession,
  confirmSession,
  createPlanningSession,
  planIdFromSelected,
  selectedFromPlanId
} from './SessionLogic';

export class TripSessionStore {
  private static planning: TripSession | null = null;
  private static locked: TripSession | null = null;
  private static archived: TripSession[] = [];

  static clearAll(): void {
    TripSessionStore.planning = null;
    TripSessionStore.locked = null;
    TripSessionStore.archived = [];
  }

  static getPlanning(): TripSession | null {
    if (TripSessionStore.planning === null) {
      return null;
    }
    return cloneTripSession(TripSessionStore.planning);
  }

  static getLocked(): TripSession | null {
    if (TripSessionStore.locked === null) {
      return null;
    }
    return cloneTripSession(TripSessionStore.locked);
  }

  /** Start or replace the current planning attempt from a fresh recommendation set. */
  static beginPlanning(
    scenario: Scenario,
    recommendationSet: RecommendationSet,
    planId: string = ''
  ): TripSession {
    const session: TripSession = createPlanningSession(scenario, recommendationSet, planId);
    TripSessionStore.planning = session;
    return cloneTripSession(session);
  }

  /** Update selected plan while still planning (does not lock). */
  static selectPlan(planId: string): TripSession | null {
    if (TripSessionStore.planning === null) {
      return null;
    }
    if (TripSessionStore.planning.status !== 'planning') {
      return cloneTripSession(TripSessionStore.planning);
    }
    const keepId: string = TripSessionStore.planning.id;
    const next: TripSession = createPlanningSession(
      TripSessionStore.planning.scenario,
      TripSessionStore.planning.recommendationSet,
      planId,
      new Date().toISOString()
    );
    next.id = keepId;
    next.selected = selectedFromPlanId(planId);
    TripSessionStore.planning = next;
    return cloneTripSession(next);
  }

  /**
   * Confirm current planning session → locked.
   * Archives any previously locked session (closed) first.
   * meetingName/address are labels only — coordinates stay engine-owned.
   */
  static confirm(
    planId: string = '',
    meetingName: string = '',
    meetingAddress: string = ''
  ): TripSession | null {
    if (TripSessionStore.planning === null) {
      return null;
    }
    const pick: string = planId.length > 0
      ? planId
      : planIdFromSelected(TripSessionStore.planning.selected);

    let meetingLabel: NamedPoint | null = null;
    if (meetingName.length > 0 || meetingAddress.length > 0) {
      meetingLabel = new NamedPoint(0, 0, meetingName, meetingAddress);
    }

    const confirmed: TripSession = confirmSession(
      TripSessionStore.planning,
      pick,
      new Date().toISOString(),
      meetingLabel
    );
    if (confirmed.status !== SESSION_CONFIRMED) {
      return null;
    }

    if (TripSessionStore.locked !== null) {
      TripSessionStore.archived.push(closeSession(TripSessionStore.locked));
    }
    TripSessionStore.locked = confirmed;
    TripSessionStore.planning = null;
    return cloneTripSession(confirmed);
  }

  /**
   * Explicit re-plan: close locked session (if any) and clear planning so UI can start fresh.
   * Does not mutate locked snapshot fields — archives a closed copy.
   */
  static replan(): void {
    if (TripSessionStore.locked !== null) {
      TripSessionStore.archived.push(closeSession(TripSessionStore.locked));
      TripSessionStore.locked = null;
    }
    TripSessionStore.planning = null;
  }

  static archiveCount(): number {
    return TripSessionStore.archived.length;
  }
}
