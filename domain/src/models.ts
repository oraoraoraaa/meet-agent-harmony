/**
 * MeetAgent domain models (scaffold).
 * Keep serializable and UI-agnostic.
 */

export type MobilityMode = 'walking' | 'bicycle' | 'transit';

export type DataSource = 'live' | 'live_with_fallback' | 'estimate';

export interface GeoPoint {
  readonly lon: number;
  readonly lat: number;
}

export interface NamedPoint extends GeoPoint {
  readonly name?: string;
  readonly address?: string;
}

export interface Constraints {
  readonly allowedModes: readonly MobilityMode[];
  /** Soft cap used for filtering / ranking walk options. */
  readonly maxPassengerWalkMin?: number;
  readonly maxPassengerBikeMin?: number;
  readonly avoidTransit?: boolean;
  /** Free-form notes from the agent (luggage, rain, …). */
  readonly notes?: string;
}

export interface Scenario {
  readonly driver: NamedPoint;
  readonly passenger: NamedPoint;
  /** City name/code for transit planning when required by map provider. */
  readonly city?: string;
  readonly constraints?: Constraints;
}

export interface RoutePoint {
  readonly point: GeoPoint;
  /** Cumulative driving seconds from driver start. */
  readonly driverSecs: number;
  readonly metersFromStart: number;
}

export interface Candidate {
  readonly routeIndex: number;
  readonly point: GeoPoint;
  readonly driverEtaMin: number;
  readonly passengerStraightM: number;
}

export interface EvaluatedOption {
  readonly meetingPoint: GeoPoint;
  readonly routeIndex: number;
  readonly mode: MobilityMode;
  readonly driverEtaMin: number;
  readonly passengerEtaMin: number;
  readonly completionMin: number;
  readonly score: number;
}

export interface Suggestion {
  readonly mode: MobilityMode;
  readonly recommended: boolean;
  readonly meetingPoint: NamedPoint;
  readonly driverEtaMin: number;
  readonly passengerEtaMin: number;
  readonly completionMin: number;
  readonly driverSavedMin: number;
  readonly score: number;
  readonly rationale: string;
  readonly driverRoutePolyline: readonly GeoPoint[];
  readonly passengerPathPolyline: readonly GeoPoint[];
}

export interface StayPutSuggestion {
  readonly recommended: boolean;
  readonly driverEtaMin: number;
  readonly completionMin: number;
  readonly meetingPoint: NamedPoint;
  readonly rationale: string;
  readonly driverRoutePolyline: readonly GeoPoint[];
}

export interface RecommendationSet {
  readonly generatedAt: string;
  readonly dataSource: DataSource;
  readonly passengerStart: NamedPoint;
  readonly driverStart: NamedPoint;
  readonly stayPut: StayPutSuggestion;
  readonly suggestions: readonly Suggestion[];
}

export type SessionStatus = 'planning' | 'confirmed' | 'closed';

export type SelectedPlan =
  | { readonly kind: 'stayPut' }
  | { readonly kind: 'suggestion'; readonly index: number };

export interface TripSession {
  readonly id: string;
  readonly status: SessionStatus;
  readonly scenario: Scenario;
  readonly recommendationSet: RecommendationSet;
  readonly selected: SelectedPlan;
  readonly lockedAt?: string;
}
