/**
 * Pure geometry helpers for schematic polyline preview (no Map Kit required).
 */

import { GeoPoint } from '../../domain/Models';

export class CanvasPoint {
  x: number = 0;
  y: number = 0;

  constructor(x: number = 0, y: number = 0) {
    this.x = x;
    this.y = y;
  }
}

export class PolylineBounds {
  minLon: number = 0;
  maxLon: number = 0;
  minLat: number = 0;
  maxLat: number = 0;
}

export function computeBounds(polylines: GeoPoint[][]): PolylineBounds {
  const b: PolylineBounds = new PolylineBounds();
  let init: boolean = false;
  for (let i = 0; i < polylines.length; i++) {
    const line: GeoPoint[] = polylines[i];
    for (let j = 0; j < line.length; j++) {
      const p: GeoPoint = line[j];
      if (!init) {
        b.minLon = p.lon;
        b.maxLon = p.lon;
        b.minLat = p.lat;
        b.maxLat = p.lat;
        init = true;
      } else {
        if (p.lon < b.minLon) {
          b.minLon = p.lon;
        }
        if (p.lon > b.maxLon) {
          b.maxLon = p.lon;
        }
        if (p.lat < b.minLat) {
          b.minLat = p.lat;
        }
        if (p.lat > b.maxLat) {
          b.maxLat = p.lat;
        }
      }
    }
  }
  if (!init) {
    b.minLon = 0;
    b.maxLon = 1;
    b.minLat = 0;
    b.maxLat = 1;
  }
  // pad
  const dLon: number = Math.max(0.002, (b.maxLon - b.minLon) * 0.15);
  const dLat: number = Math.max(0.002, (b.maxLat - b.minLat) * 0.15);
  b.minLon -= dLon;
  b.maxLon += dLon;
  b.minLat -= dLat;
  b.maxLat += dLat;
  return b;
}

export function projectPoint(
  p: GeoPoint,
  bounds: PolylineBounds,
  width: number,
  height: number,
  padding: number = 12
): CanvasPoint {
  const usableW: number = Math.max(1, width - padding * 2);
  const usableH: number = Math.max(1, height - padding * 2);
  const lonSpan: number = Math.max(1e-9, bounds.maxLon - bounds.minLon);
  const latSpan: number = Math.max(1e-9, bounds.maxLat - bounds.minLat);
  const x: number = padding + ((p.lon - bounds.minLon) / lonSpan) * usableW;
  // invert y (north up)
  const y: number = padding + (1 - (p.lat - bounds.minLat) / latSpan) * usableH;
  return new CanvasPoint(x, y);
}

export function projectPolyline(
  line: GeoPoint[],
  bounds: PolylineBounds,
  width: number,
  height: number
): CanvasPoint[] {
  const out: CanvasPoint[] = [];
  for (let i = 0; i < line.length; i++) {
    out.push(projectPoint(line[i], bounds, width, height));
  }
  return out;
}
