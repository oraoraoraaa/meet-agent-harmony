/**
 * Offline estimate providers: straight-line geometry + constant speed models.
 * Always available; label outputs as dataSource=estimate.
 */

import type { GeoPoint, MobilityMode, RoutePoint } from './models.ts';
import { haversineM } from './geo.ts';

/** Urban driving effective speed (km/h). */
export const EST_DRIVE_KMH = 28;
/** Walking effective speed (km/h). */
export const EST_WALK_KMH = 4.5;
/** Bicycle effective speed (km/h). */
export const EST_BIKE_KMH = 12;
/** Transit door-to-door effective speed (km/h). */
export const EST_TRANSIT_KMH = 20;

export function speedKmhForMode(mode: MobilityMode): number {
  switch (mode) {
    case 'walking':
      return EST_WALK_KMH;
    case 'bicycle':
      return EST_BIKE_KMH;
    case 'transit':
      return EST_TRANSIT_KMH;
  }
}

export function etaMinFromDistanceM(distanceM: number, speedKmh: number): number {
  if (distanceM <= 0) return 0;
  if (speedKmh <= 0) return Number.POSITIVE_INFINITY;
  return (distanceM / 1000 / speedKmh) * 60;
}

/** Linear interpolate lon/lat (good enough for short urban segments). */
export function interpolatePoints(from: GeoPoint, to: GeoPoint, segments: number): GeoPoint[] {
  const n = Math.max(1, Math.floor(segments));
  const out: GeoPoint[] = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    out.push({
      lon: from.lon + (to.lon - from.lon) * t,
      lat: from.lat + (to.lat - from.lat) * t,
    });
  }
  return out;
}

/**
 * Build a straight driving route with cumulative time/distance along vertices.
 * densify so candidate generation has enough samples.
 */
export function buildStraightDrivingRoute(
  from: GeoPoint,
  to: GeoPoint,
  options?: { segmentM?: number; driveKmh?: number },
): { polyline: GeoPoint[]; route: RoutePoint[] } {
  const segmentM = options?.segmentM ?? 120;
  const driveKmh = options?.driveKmh ?? EST_DRIVE_KMH;
  const totalM = haversineM(from, to);
  const segments = Math.max(4, Math.ceil(totalM / segmentM));
  const polyline = interpolatePoints(from, to, segments);
  const route: RoutePoint[] = [];
  let metersFromStart = 0;
  route.push({ point: polyline[0]!, driverSecs: 0, metersFromStart: 0 });
  for (let i = 1; i < polyline.length; i++) {
    const prev = polyline[i - 1]!;
    const cur = polyline[i]!;
    metersFromStart += haversineM(prev, cur);
    const driverSecs = etaMinFromDistanceM(metersFromStart, driveKmh) * 60;
    route.push({ point: cur, driverSecs, metersFromStart });
  }
  // Ensure exact endpoint
  if (route.length > 0) {
    const last = route[route.length - 1]!;
    route[route.length - 1] = {
      point: { lon: to.lon, lat: to.lat },
      driverSecs: last.driverSecs,
      metersFromStart: last.metersFromStart,
    };
    polyline[polyline.length - 1] = { lon: to.lon, lat: to.lat };
  }
  return { polyline, route };
}

export function estimatePassengerPath(
  mode: MobilityMode,
  from: GeoPoint,
  to: GeoPoint,
): { etaMin: number; polyline: GeoPoint[]; distanceM: number } {
  const distanceM = haversineM(from, to);
  const etaMin = etaMinFromDistanceM(distanceM, speedKmhForMode(mode));
  const segments = Math.max(2, Math.ceil(distanceM / 150));
  return {
    etaMin,
    distanceM,
    polyline: interpolatePoints(from, to, segments),
  };
}
