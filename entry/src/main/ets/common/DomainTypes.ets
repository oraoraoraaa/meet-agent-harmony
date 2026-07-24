/**
 * MeetAgent domain models — ArkTS port of domain/src/models.ts concepts.
 * Full types live in domain/Models.ets; this file remains a thin alias surface.
 */

export type MobilityMode = string;
export type DataSource = string;

export const MODE_WALKING: MobilityMode = 'walking';
export const MODE_BICYCLE: MobilityMode = 'bicycle';
export const MODE_TRANSIT: MobilityMode = 'transit';

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
}

export class Constraints {
  allowedModes: MobilityMode[] = [MODE_WALKING, MODE_BICYCLE, MODE_TRANSIT];
  maxPassengerWalkMin: number = -1;
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
