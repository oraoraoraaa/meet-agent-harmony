/**
 * MeetAgent domain models — ArkTS port of domain/src/models.ts.
 * Keep contracts in sync with portable TS domain.
 */

export type MobilityMode = string;
export type DataSource = string;
export type SessionStatus = string;

export const MODE_WALKING: MobilityMode = 'walking';
export const MODE_BICYCLE: MobilityMode = 'bicycle';
export const MODE_TRANSIT: MobilityMode = 'transit';

export const DATA_LIVE: DataSource = 'live';
export const DATA_LIVE_FALLBACK: DataSource = 'live_with_fallback';
export const DATA_ESTIMATE: DataSource = 'estimate';

export const SESSION_PLANNING: SessionStatus = 'planning';
export const SESSION_CONFIRMED: SessionStatus = 'confirmed';
export const SESSION_CLOSED: SessionStatus = 'closed';

export class GeoPoint {
  lon: number = 0;
  lat: number = 0;

  constructor(lon: number = 0, lat: number = 0) {
    this.lon = lon;
    this.lat = lat;
  }
}

export class NamedPoint {
  lon: number = 0;
  lat: number = 0;
  name: string = '';
  address: string = '';

  constructor(lon: number = 0, lat: number = 0, name: string = '', address: string = '') {
    this.lon = lon;
    this.lat = lat;
    this.name = name;
    this.address = address;
  }

  toGeo(): GeoPoint {
    return new GeoPoint(this.lon, this.lat);
  }
}

export class Constraints {
  allowedModes: MobilityMode[] = [MODE_WALKING, MODE_BICYCLE, MODE_TRANSIT];
  maxPassengerWalkMin: number = -1; // <0 means unset
  maxPassengerBikeMin: number = -1;
  avoidTransit: boolean = false;
  notes: string = '';
}

export class Scenario {
  driver: NamedPoint = new NamedPoint();
  passenger: NamedPoint = new NamedPoint();
  city: string = '';
  constraints: Constraints = new Constraints();
}

export class RoutePoint {
  point: GeoPoint = new GeoPoint();
  driverSecs: number = 0;
  metersFromStart: number = 0;

  constructor(point: GeoPoint = new GeoPoint(), driverSecs: number = 0, metersFromStart: number = 0) {
    this.point = point;
    this.driverSecs = driverSecs;
    this.metersFromStart = metersFromStart;
  }
}

export class Candidate {
  routeIndex: number = 0;
  point: GeoPoint = new GeoPoint();
  driverEtaMin: number = 0;
  passengerStraightM: number = 0;
}

export class EvaluatedOption {
  meetingPoint: GeoPoint = new GeoPoint();
  routeIndex: number = 0;
  mode: MobilityMode = MODE_WALKING;
  driverEtaMin: number = 0;
  passengerEtaMin: number = 0;
  completionMin: number = 0;
  score: number = 0;
  passengerPolyline: GeoPoint[] = [];
}

export class Suggestion {
  mode: MobilityMode = MODE_WALKING;
  recommended: boolean = false;
  meetingPoint: NamedPoint = new NamedPoint();
  driverEtaMin: number = 0;
  passengerEtaMin: number = 0;
  completionMin: number = 0;
  driverSavedMin: number = 0;
  score: number = 0;
  rationale: string = '';
  driverRoutePolyline: GeoPoint[] = [];
  passengerPathPolyline: GeoPoint[] = [];
}

export class StayPutSuggestion {
  recommended: boolean = true;
  driverEtaMin: number = 0;
  completionMin: number = 0;
  meetingPoint: NamedPoint = new NamedPoint();
  rationale: string = '';
  driverRoutePolyline: GeoPoint[] = [];
}

export class RecommendationSet {
  generatedAt: string = '';
  dataSource: DataSource = DATA_ESTIMATE;
  passengerStart: NamedPoint = new NamedPoint();
  driverStart: NamedPoint = new NamedPoint();
  stayPut: StayPutSuggestion = new StayPutSuggestion();
  suggestions: Suggestion[] = [];
}

export class SelectedPlan {
  kind: string = 'stayPut'; // 'stayPut' | 'suggestion'
  index: number = 0;
}

export class TripSession {
  id: string = '';
  status: SessionStatus = SESSION_PLANNING;
  scenario: Scenario = new Scenario();
  recommendationSet: RecommendationSet = new RecommendationSet();
  selected: SelectedPlan = new SelectedPlan();
  lockedAt: string = '';
}

export function modeLabelZh(mode: MobilityMode): string {
  if (mode === MODE_WALKING) {
    return '步行';
  }
  if (mode === MODE_BICYCLE) {
    return '骑行';
  }
  if (mode === MODE_TRANSIT) {
    return '公交';
  }
  return mode;
}

export function dataSourceLabelZh(source: DataSource): string {
  if (source === DATA_LIVE) {
    return '实时';
  }
  if (source === DATA_LIVE_FALLBACK) {
    return '实时+估算';
  }
  return '估算';
}
