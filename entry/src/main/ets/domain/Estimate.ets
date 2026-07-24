import {
  GeoPoint,
  MODE_BICYCLE,
  MODE_TRANSIT,
  MODE_WALKING,
  MobilityMode,
  RoutePoint
} from './Models';
import { haversineM } from './Geo';

export const EST_DRIVE_KMH: number = 28;
export const EST_WALK_KMH: number = 4.5;
export const EST_BIKE_KMH: number = 12;
export const EST_TRANSIT_KMH: number = 20;

export function speedKmhForMode(mode: MobilityMode): number {
  if (mode === MODE_WALKING) {
    return EST_WALK_KMH;
  }
  if (mode === MODE_BICYCLE) {
    return EST_BIKE_KMH;
  }
  if (mode === MODE_TRANSIT) {
    return EST_TRANSIT_KMH;
  }
  return EST_WALK_KMH;
}

export function etaMinFromDistanceM(distanceM: number, speedKmh: number): number {
  if (distanceM <= 0) {
    return 0;
  }
  if (speedKmh <= 0) {
    return 99999;
  }
  return (distanceM / 1000 / speedKmh) * 60;
}

export function interpolatePoints(from: GeoPoint, to: GeoPoint, segments: number): GeoPoint[] {
  const n: number = Math.max(1, Math.floor(segments));
  const out: GeoPoint[] = [];
  for (let i = 0; i <= n; i++) {
    const t: number = i / n;
    out.push(new GeoPoint(
      from.lon + (to.lon - from.lon) * t,
      from.lat + (to.lat - from.lat) * t
    ));
  }
  return out;
}

export class StraightRouteBuild {
  polyline: GeoPoint[] = [];
  route: RoutePoint[] = [];
}

export function buildStraightDrivingRoute(
  from: GeoPoint,
  to: GeoPoint,
  segmentM: number = 120,
  driveKmh: number = EST_DRIVE_KMH
): StraightRouteBuild {
  const totalM: number = haversineM(from, to);
  const segments: number = Math.max(4, Math.ceil(totalM / segmentM));
  const polyline: GeoPoint[] = interpolatePoints(from, to, segments);
  const route: RoutePoint[] = [];
  let metersFromStart: number = 0;
  route.push(new RoutePoint(polyline[0], 0, 0));
  for (let i = 1; i < polyline.length; i++) {
    const prev: GeoPoint = polyline[i - 1];
    const cur: GeoPoint = polyline[i];
    metersFromStart += haversineM(prev, cur);
    const driverSecs: number = etaMinFromDistanceM(metersFromStart, driveKmh) * 60;
    route.push(new RoutePoint(cur, driverSecs, metersFromStart));
  }
  if (route.length > 0) {
    const last: RoutePoint = route[route.length - 1];
    route[route.length - 1] = new RoutePoint(new GeoPoint(to.lon, to.lat), last.driverSecs, last.metersFromStart);
    polyline[polyline.length - 1] = new GeoPoint(to.lon, to.lat);
  }
  const built: StraightRouteBuild = new StraightRouteBuild();
  built.polyline = polyline;
  built.route = route;
  return built;
}

export class PassengerPathEstimate {
  etaMin: number = 0;
  polyline: GeoPoint[] = [];
  distanceM: number = 0;
}

export function estimatePassengerPath(mode: MobilityMode, from: GeoPoint, to: GeoPoint): PassengerPathEstimate {
  const distanceM: number = haversineM(from, to);
  const etaMin: number = etaMinFromDistanceM(distanceM, speedKmhForMode(mode));
  const segments: number = Math.max(2, Math.ceil(distanceM / 150));
  const result: PassengerPathEstimate = new PassengerPathEstimate();
  result.distanceM = distanceM;
  result.etaMin = etaMin;
  result.polyline = interpolatePoints(from, to, segments);
  return result;
}
