/**
 * In-memory draft points shared between Home map, PlanPage, ChatPage.
 * Process-lifetime only (no dual-phone sync).
 */

export class TripDraft {
  driverLon: number = 108.8905;
  driverLat: number = 34.2324;
  driverName: string = '司机起点';
  hasDriver: boolean = false;
  passengerLon: number = 108.9465;
  passengerLat: number = 34.2610;
  passengerName: string = '乘客位置';
  hasPassenger: boolean = false;
  city: string = '西安';
}

export class TripDraftStore {
  private static draft: TripDraft = new TripDraft();

  static get(): TripDraft {
    const d: TripDraft = new TripDraft();
    const s: TripDraft = TripDraftStore.draft;
    d.driverLon = s.driverLon;
    d.driverLat = s.driverLat;
    d.driverName = s.driverName;
    d.hasDriver = s.hasDriver;
    d.passengerLon = s.passengerLon;
    d.passengerLat = s.passengerLat;
    d.passengerName = s.passengerName;
    d.hasPassenger = s.hasPassenger;
    d.city = s.city;
    return d;
  }

  static setDriver(lon: number, lat: number, name: string, has: boolean): void {
    TripDraftStore.draft.driverLon = lon;
    TripDraftStore.draft.driverLat = lat;
    TripDraftStore.draft.driverName = name;
    TripDraftStore.draft.hasDriver = has;
  }

  static setPassenger(lon: number, lat: number, name: string, has: boolean): void {
    TripDraftStore.draft.passengerLon = lon;
    TripDraftStore.draft.passengerLat = lat;
    TripDraftStore.draft.passengerName = name;
    TripDraftStore.draft.hasPassenger = has;
  }

  static setCity(city: string): void {
    TripDraftStore.draft.city = city;
  }
}
