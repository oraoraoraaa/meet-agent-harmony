/**
 * Pure helpers for AMap Web route polylines (no HTTP).
 * Coordinates treated as GCJ-02 end-to-end by callers.
 */

import type { GeoPoint, RoutePoint } from './models.ts';
import { haversineM } from './geo.ts';

/** Decode AMap step polyline: "lon,lat;lon,lat" or space-separated pairs. */
export function decodeAmapPolyline(raw: string): GeoPoint[] {
  const text = raw.trim();
  if (text.length === 0) {
    return [];
  }
  const out: GeoPoint[] = [];
  // Prefer semicolon-separated "lon,lat;lon,lat"
  const chunks = text.indexOf(';') >= 0 ? text.split(';') : text.split(/\s+/);
  for (let i = 0; i < chunks.length; i++) {
    const part = chunks[i].trim();
    if (part.length === 0) {
      continue;
    }
    const comma = part.indexOf(',');
    if (comma <= 0) {
      continue;
    }
    const lon = Number(part.substring(0, comma));
    const lat = Number(part.substring(comma + 1));
    if (!Number.isFinite(lon) || !Number.isFinite(lat)) {
      continue;
    }
    out.push({ lon, lat });
  }
  return out;
}

/** Concatenate multiple AMap step polylines, dropping duplicate joints. */
export function mergePolylines(parts: readonly (readonly GeoPoint[])[]): GeoPoint[] {
  const out: GeoPoint[] = [];
  for (let p = 0; p < parts.length; p++) {
    const poly = parts[p];
    for (let i = 0; i < poly.length; i++) {
      const pt = poly[i];
      if (out.length > 0) {
        const last = out[out.length - 1];
        if (Math.abs(last.lon - pt.lon) < 1e-7 && Math.abs(last.lat - pt.lat) < 1e-7) {
          continue;
        }
      }
      out.push({ lon: pt.lon, lat: pt.lat });
    }
  }
  return out;
}

/**
 * Build dense RoutePoint samples from a driving polyline + total duration.
 * driverSecs is distributed by cumulative path distance (not straight-line).
 */
export function routePointsFromPolyline(
  polyline: readonly GeoPoint[],
  durationSec: number,
): RoutePoint[] {
  if (polyline.length === 0) {
    return [];
  }
  const route: RoutePoint[] = [];
  let meters = 0;
  route.push({
    point: { lon: polyline[0].lon, lat: polyline[0].lat },
    driverSecs: 0,
    metersFromStart: 0,
  });
  for (let i = 1; i < polyline.length; i++) {
    const prev = polyline[i - 1];
    const cur = polyline[i];
    meters += haversineM(prev, cur);
    route.push({
      point: { lon: cur.lon, lat: cur.lat },
      driverSecs: 0,
      metersFromStart: meters,
    });
  }
  const totalM = meters > 0 ? meters : 1;
  const totalSec = durationSec > 0 ? durationSec : 0;
  for (let i = 0; i < route.length; i++) {
    const frac = route[i].metersFromStart / totalM;
    route[i] = {
      point: route[i].point,
      driverSecs: totalSec * frac,
      metersFromStart: route[i].metersFromStart,
    };
  }
  return route;
}

/** Ensure endpoints match from/to when AMap slightly snaps them. */
export function ensureEndpoints(
  polyline: readonly GeoPoint[],
  from: GeoPoint,
  to: GeoPoint,
): GeoPoint[] {
  if (polyline.length === 0) {
    return [
      { lon: from.lon, lat: from.lat },
      { lon: to.lon, lat: to.lat },
    ];
  }
  const out: GeoPoint[] = polyline.map((p) => ({ lon: p.lon, lat: p.lat }));
  out[0] = { lon: from.lon, lat: from.lat };
  out[out.length - 1] = { lon: to.lon, lat: to.lat };
  return out;
}
