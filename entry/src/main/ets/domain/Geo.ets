import { GeoPoint } from './Models';

const EARTH_RADIUS_M: number = 6371000;

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/** Great-circle distance in meters. */
export function haversineM(a: GeoPoint, b: GeoPoint): number {
  const dLat: number = toRad(b.lat - a.lat);
  const dLon: number = toRad(b.lon - a.lon);
  const lat1: number = toRad(a.lat);
  const lat2: number = toRad(b.lat);
  const h: number =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}
