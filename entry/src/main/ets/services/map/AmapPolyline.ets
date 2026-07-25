/**
 * AMap polyline decode + RoutePoint builder (ArkTS port of domain/src/amapPolyline.ts).
 * Keep pure — no NetworkKit.
 */

import { GeoPoint, RoutePoint } from '../../domain/Models';
import { haversineM } from '../../domain/Geo';

export function decodeAmapPolyline(raw: string): GeoPoint[] {
  const text: string = raw.trim();
  if (text.length === 0) {
    return [];
  }
  const out: GeoPoint[] = [];
  const chunks: string[] = text.indexOf(';') >= 0 ? text.split(';') : text.split(' ');
  for (let i = 0; i < chunks.length; i++) {
    const part: string = chunks[i].trim();
    if (part.length === 0) {
      continue;
    }
    const comma: number = part.indexOf(',');
    if (comma <= 0) {
      continue;
    }
    const lon: number = Number(part.substring(0, comma));
    const lat: number = Number(part.substring(comma + 1));
    if (isNaN(lon) || isNaN(lat)) {
      continue;
    }
    out.push(new GeoPoint(lon, lat));
  }
  return out;
}

export function mergePolylines(parts: GeoPoint[][]): GeoPoint[] {
  const out: GeoPoint[] = [];
  for (let p = 0; p < parts.length; p++) {
    const poly: GeoPoint[] = parts[p];
    for (let i = 0; i < poly.length; i++) {
      const pt: GeoPoint = poly[i];
      if (out.length > 0) {
        const last: GeoPoint = out[out.length - 1];
        if (Math.abs(last.lon - pt.lon) < 1e-7 && Math.abs(last.lat - pt.lat) < 1e-7) {
          continue;
        }
      }
      out.push(new GeoPoint(pt.lon, pt.lat));
    }
  }
  return out;
}

export function routePointsFromPolyline(polyline: GeoPoint[], durationSec: number): RoutePoint[] {
  if (polyline.length === 0) {
    return [];
  }
  const route: RoutePoint[] = [];
  let meters: number = 0;
  route.push(new RoutePoint(new GeoPoint(polyline[0].lon, polyline[0].lat), 0, 0));
  for (let i = 1; i < polyline.length; i++) {
    const prev: GeoPoint = polyline[i - 1];
    const cur: GeoPoint = polyline[i];
    meters += haversineM(prev, cur);
    route.push(new RoutePoint(new GeoPoint(cur.lon, cur.lat), 0, meters));
  }
  const totalM: number = meters > 0 ? meters : 1;
  const totalSec: number = durationSec > 0 ? durationSec : 0;
  for (let i = 0; i < route.length; i++) {
    const frac: number = route[i].metersFromStart / totalM;
    route[i] = new RoutePoint(
      new GeoPoint(route[i].point.lon, route[i].point.lat),
      totalSec * frac,
      route[i].metersFromStart
    );
  }
  return route;
}

export function ensureEndpoints(polyline: GeoPoint[], from: GeoPoint, to: GeoPoint): GeoPoint[] {
  if (polyline.length === 0) {
    return [new GeoPoint(from.lon, from.lat), new GeoPoint(to.lon, to.lat)];
  }
  const out: GeoPoint[] = [];
  for (let i = 0; i < polyline.length; i++) {
    out.push(new GeoPoint(polyline[i].lon, polyline[i].lat));
  }
  out[0] = new GeoPoint(from.lon, from.lat);
  out[out.length - 1] = new GeoPoint(to.lon, to.lat);
  return out;
}
