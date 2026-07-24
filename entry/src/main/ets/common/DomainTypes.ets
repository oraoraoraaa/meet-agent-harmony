/**
 * MeetAgent domain models — ArkTS port of domain/src/models.ts concepts.
 * Keep in sync with portable TS domain when engine lands in Phase 1.
 */

export type MobilityMode = 'walking' | 'bicycle' | 'transit';

export type DataSource = 'live' | 'live_with_fallback' | 'estimate';

export interface GeoPoint {
  lon: number;
  lat: number;
}

export interface NamedPoint {
  lon: number;
  lat: number;
  name?: string;
  address?: string;
}

export interface Constraints {
  allowedModes: MobilityMode[];
  maxPassengerWalkMin?: number;
  maxPassengerBikeMin?: number;
  avoidTransit?: boolean;
  notes?: string;
}

export interface Scenario {
  driver: NamedPoint;
  passenger: NamedPoint;
  city?: string;
  constraints?: Constraints;
}
