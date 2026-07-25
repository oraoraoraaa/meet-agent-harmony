/**
 * AMap Web REST map provider (GCJ-02).
 *
 * Products used (enable on AMap console Web service key):
 *  - 路径规划: direction/driving, walking, bicycling, transit/integrated
 *  - 地理编码: geocode/regeo
 *  - 搜索: place/text
 *
 * Never logs the key. Failures throw so Hybrid can fall back to estimate.
 */

import { http } from '@kit.NetworkKit';
import {
  DrivingRouteResult,
  PassengerPathResult
} from '../../domain/RunAnalysis';
import {
  DATA_LIVE,
  GeoPoint,
  MODE_BICYCLE,
  MODE_TRANSIT,
  MODE_WALKING,
  MobilityMode
} from '../../domain/Models';
import {
  decodeAmapPolyline,
  ensureEndpoints,
  mergePolylines,
  routePointsFromPolyline
} from './AmapPolyline';

const AMAP_BASE: string = 'https://restapi.amap.com/v3';
const DEFAULT_TIMEOUT_MS: number = 12000;

export class PoiHit {
  name: string = '';
  address: string = '';
  lon: number = 0;
  lat: number = 0;
  distanceM: number = -1;
}

function encodeQuery(params: string[]): string {
  // params already "k=v" with values URL-encoded by caller
  return params.join('&');
}

function urlEncode(value: string): string {
  // Prefer encodeURIComponent; ArkTS supports it in modern runtimes.
  try {
    return encodeURIComponent(value);
  } catch (e) {
    const _ignored: Object = e as Object;
    return value;
  }
}

function asObject(value: Object | null | undefined): Record<string, Object> | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value !== 'object') {
    return null;
  }
  return value as Record<string, Object>;
}

function asArray(value: Object | null | undefined): Object[] {
  if (value === null || value === undefined) {
    return [];
  }
  if (value instanceof Array) {
    return value as Object[];
  }
  return [];
}

function asString(value: Object | null | undefined, fallback: string = ''): string {
  if (typeof value === 'string') {
    return value as string;
  }
  if (typeof value === 'number') {
    return `${value as number}`;
  }
  return fallback;
}

function asNumber(value: Object | null | undefined, fallback: number = 0): number {
  if (typeof value === 'number') {
    const n: number = value as number;
    if (isNaN(n)) {
      return fallback;
    }
    return n;
  }
  if (typeof value === 'string') {
    const n: number = Number(value as string);
    if (isNaN(n)) {
      return fallback;
    }
    return n;
  }
  return fallback;
}

function lonLatParam(p: GeoPoint): string {
  return `${p.lon},${p.lat}`;
}

export class AmapWebMapProvider {
  private key: string = '';
  private timeoutMs: number = DEFAULT_TIMEOUT_MS;

  constructor(mapWebKey: string, timeoutMs: number = DEFAULT_TIMEOUT_MS) {
    this.key = mapWebKey.trim();
    this.timeoutMs = timeoutMs > 0 ? timeoutMs : DEFAULT_TIMEOUT_MS;
  }

  hasKey(): boolean {
    return this.key.length > 0;
  }

  async getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> {
    const path: string = '/direction/driving';
    const query: string = encodeQuery([
      `key=${urlEncode(this.key)}`,
      `origin=${urlEncode(lonLatParam(from))}`,
      `destination=${urlEncode(lonLatParam(to))}`,
      'extensions=all',
      'strategy=0'
    ]);
    const root: Record<string, Object> = await this.getJson(`${AMAP_BASE}${path}?${query}`);
    this.assertStatus(root, 'driving');
    const routeObj: Record<string, Object> | null = asObject(root['route']);
    if (routeObj === null) {
      throw new Error('amap driving: missing route');
    }
    const paths: Object[] = asArray(routeObj['paths']);
    if (paths.length === 0) {
      throw new Error('amap driving: empty paths');
    }
    const firstPath: Record<string, Object> | null = asObject(paths[0]);
    if (firstPath === null) {
      throw new Error('amap driving: bad path');
    }
    const durationSec: number = asNumber(firstPath['duration'], 0);
    const steps: Object[] = asArray(firstPath['steps']);
    const stepPolys: GeoPoint[][] = [];
    for (let i = 0; i < steps.length; i++) {
      const step: Record<string, Object> | null = asObject(steps[i]);
      if (step === null) {
        continue;
      }
      const polyStr: string = asString(step['polyline'], '');
      const decoded: GeoPoint[] = decodeAmapPolyline(polyStr);
      if (decoded.length > 0) {
        stepPolys.push(decoded);
      }
    }
    let polyline: GeoPoint[] = mergePolylines(stepPolys);
    if (polyline.length < 2) {
      // Some responses put polyline only on path
      const pathPoly: string = asString(firstPath['polyline'], '');
      polyline = decodeAmapPolyline(pathPoly);
    }
    polyline = ensureEndpoints(polyline, from, to);
    if (polyline.length < 2) {
      throw new Error('amap driving: empty polyline');
    }
    const out: DrivingRouteResult = new DrivingRouteResult();
    out.polyline = polyline;
    out.route = routePointsFromPolyline(polyline, durationSec);
    out.dataSource = DATA_LIVE;
    return out;
  }

  async getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string
  ): Promise<PassengerPathResult> {
    if (mode === MODE_WALKING) {
      return this.directionSimple(`${AMAP_BASE}/direction/walking`, from, to);
    }
    if (mode === MODE_BICYCLE) {
      // Official bicycle path is v4; fall back to walking live before Hybrid estimate.
      try {
        return await this.directionBicyclingV4(from, to);
      } catch (e1) {
        const _ignored1: Object = e1 as Object;
        try {
          return await this.directionSimple(`${AMAP_BASE}/direction/walking`, from, to);
        } catch (e2) {
          const _ignored2: Object = e2 as Object;
          // ArkTS: throw only Error (not arbitrary catch bindings).
          throw new Error('amap bicycle unavailable (v4 + walking fallback failed)');
        }
      }
    }
    if (mode === MODE_TRANSIT) {
      return this.directionTransit(from, to, city);
    }
    return this.directionSimple(`${AMAP_BASE}/direction/walking`, from, to);
  }

  /**
   * Human place label for UI: nearest POI name preferred, then short address.
   * Never invents coordinates — only labels a known GCJ-02 point.
   */
  async reverseGeocode(point: GeoPoint): Promise<string> {
    return this.reverseGeocodeLabel(point);
  }

  async reverseGeocodeLabel(point: GeoPoint): Promise<string> {
    const query: string = encodeQuery([
      `key=${urlEncode(this.key)}`,
      `location=${urlEncode(lonLatParam(point))}`,
      'extensions=all',
      'radius=200',
      'homeorcorp=0'
    ]);
    const root: Record<string, Object> = await this.getJson(`${AMAP_BASE}/geocode/regeo?${query}`);
    this.assertStatus(root, 'regeo');
    const regeocode: Record<string, Object> | null = asObject(root['regeocode']);
    if (regeocode === null) {
      return '附近地点';
    }
    // Prefer nearby POI (what users understand)
    const pois: Object[] = asArray(regeocode['pois']);
    for (let i = 0; i < pois.length; i++) {
      const poi: Record<string, Object> | null = asObject(pois[i]);
      if (poi === null) {
        continue;
      }
      const name: string = asString(poi['name'], '').trim();
      if (name.length > 0) {
        const addr: string = asString(poi['address'], '').trim();
        if (addr.length > 0 && addr.indexOf(name) < 0) {
          return `${name} · ${addr}`;
        }
        return name;
      }
    }
    const aois: Object[] = asArray(regeocode['aois']);
    for (let i = 0; i < aois.length; i++) {
      const aoi: Record<string, Object> | null = asObject(aois[i]);
      if (aoi === null) {
        continue;
      }
      const name: string = asString(aoi['name'], '').trim();
      if (name.length > 0) {
        return name;
      }
    }
    const formatted: string = asString(regeocode['formatted_address'], '').trim();
    if (formatted.length > 0) {
      // Drop long province prefix when possible
      return formatted.length > 28 ? formatted.substring(formatted.length - 28) : formatted;
    }
    const addrComp: Record<string, Object> | null = asObject(regeocode['addressComponent']);
    if (addrComp !== null) {
      const township: string = asString(addrComp['township'], '');
      const district: string = asString(addrComp['district'], '');
      const streetNode: Record<string, Object> | null = asObject(addrComp['streetNumber']);
      let street: string = '';
      if (streetNode !== null) {
        street = `${asString(streetNode['street'], '')}${asString(streetNode['number'], '')}`;
      }
      const joined: string = `${district}${township}${street}`.trim();
      if (joined.length > 0) {
        return joined;
      }
    }
    return '附近地点';
  }

  async searchPoi(query: string, nearLon: number, nearLat: number, hasNear: boolean): Promise<string[]> {
    const hits: PoiHit[] = await this.searchPoiDetailed(query, nearLon, nearLat, hasNear, '');
    const names: string[] = [];
    for (let i = 0; i < hits.length; i++) {
      if (hits[i].name.length > 0) {
        names.push(hits[i].name);
      }
    }
    return names;
  }

  /** Rich POI hits for UI pick (coords from AMap only — never invent). */
  async searchPoiDetailed(
    query: string,
    nearLon: number,
    nearLat: number,
    hasNear: boolean,
    city: string
  ): Promise<PoiHit[]> {
    const q: string = query.trim();
    if (q.length === 0) {
      return [];
    }
    const parts: string[] = [
      `key=${urlEncode(this.key)}`,
      `keywords=${urlEncode(q)}`,
      'offset=8',
      'page=1',
      'extensions=base'
    ];
    if (city.trim().length > 0) {
      parts.push(`city=${urlEncode(city.trim())}`);
      parts.push('citylimit=true');
    }
    if (hasNear) {
      parts.push(`location=${urlEncode(`${nearLon},${nearLat}`)}`);
      parts.push('radius=3000');
      parts.push('sortrule=distance');
    }
    const root: Record<string, Object> = await this.getJson(`${AMAP_BASE}/place/text?${encodeQuery(parts)}`);
    this.assertStatus(root, 'place');
    const pois: Object[] = asArray(root['pois']);
    const out: PoiHit[] = [];
    for (let i = 0; i < pois.length; i++) {
      const poi: Record<string, Object> | null = asObject(pois[i]);
      if (poi === null) {
        continue;
      }
      const name: string = asString(poi['name'], '');
      const address: string = asString(poi['address'], '');
      const loc: string = asString(poi['location'], '');
      if (name.length === 0 || loc.length === 0) {
        continue;
      }
      const comma: number = loc.indexOf(',');
      if (comma <= 0) {
        continue;
      }
      const lon: number = Number(loc.substring(0, comma));
      const lat: number = Number(loc.substring(comma + 1));
      if (isNaN(lon) || isNaN(lat)) {
        continue;
      }
      const hit: PoiHit = new PoiHit();
      hit.name = name;
      hit.address = address;
      hit.lon = lon;
      hit.lat = lat;
      hit.distanceM = asNumber(poi['distance'], -1);
      out.push(hit);
    }
    return out;
  }

  private async directionBicyclingV4(from: GeoPoint, to: GeoPoint): Promise<PassengerPathResult> {
    const query: string = encodeQuery([
      `key=${urlEncode(this.key)}`,
      `origin=${urlEncode(lonLatParam(from))}`,
      `destination=${urlEncode(lonLatParam(to))}`
    ]);
    // v4 response shape differs slightly from v3
    const root: Record<string, Object> = await this.getJson(
      `https://restapi.amap.com/v4/direction/bicycling?${query}`
    );
    // v4 uses errcode/errmsg or status
    const errcode: number = asNumber(root['errcode'], -1);
    if (errcode !== -1 && errcode !== 0) {
      const errmsg: string = asString(root['errmsg'], 'bicycling error');
      throw new Error(`amap bicycling v4: ${errmsg}`);
    }
    const status: string = asString(root['status'], '');
    if (status.length > 0 && status !== '1') {
      this.assertStatus(root, 'bicycling-v4');
    }
    const data: Record<string, Object> | null = asObject(root['data']);
    // Prefer data.paths[0]
    let firstPath: Record<string, Object> | null = null;
    if (data !== null) {
      const paths: Object[] = asArray(data['paths']);
      if (paths.length > 0) {
        firstPath = asObject(paths[0]);
      }
    }
    if (firstPath === null) {
      const routeObj: Record<string, Object> | null = asObject(root['route']);
      if (routeObj !== null) {
        const paths2: Object[] = asArray(routeObj['paths']);
        if (paths2.length > 0) {
          firstPath = asObject(paths2[0]);
        }
      }
    }
    if (firstPath === null) {
      throw new Error('amap bicycling v4: empty path');
    }
    const durationSec: number = asNumber(firstPath['duration'], 0);
    const steps: Object[] = asArray(firstPath['steps']);
    const stepPolys: GeoPoint[][] = [];
    for (let i = 0; i < steps.length; i++) {
      const step: Record<string, Object> | null = asObject(steps[i]);
      if (step === null) {
        continue;
      }
      const polyStr: string = asString(step['polyline'], '');
      const decoded: GeoPoint[] = decodeAmapPolyline(polyStr);
      if (decoded.length > 0) {
        stepPolys.push(decoded);
      }
    }
    let polyline: GeoPoint[] = mergePolylines(stepPolys);
    polyline = ensureEndpoints(polyline, from, to);
    const out: PassengerPathResult = new PassengerPathResult();
    out.etaMin = durationSec > 0 ? durationSec / 60 : 0;
    out.polyline = polyline;
    out.dataSource = DATA_LIVE;
    return out;
  }

  private async directionSimple(urlPathOrFull: string, from: GeoPoint, to: GeoPoint): Promise<PassengerPathResult> {
    const fullUrl: string = urlPathOrFull.indexOf('http') === 0
      ? `${urlPathOrFull}?${encodeQuery([
        `key=${urlEncode(this.key)}`,
        `origin=${urlEncode(lonLatParam(from))}`,
        `destination=${urlEncode(lonLatParam(to))}`
      ])}`
      : `${AMAP_BASE}${urlPathOrFull}?${encodeQuery([
        `key=${urlEncode(this.key)}`,
        `origin=${urlEncode(lonLatParam(from))}`,
        `destination=${urlEncode(lonLatParam(to))}`
      ])}`;
    const root: Record<string, Object> = await this.getJson(fullUrl);
    this.assertStatus(root, urlPathOrFull);
    const routeObj: Record<string, Object> | null = asObject(root['route']);
    if (routeObj === null) {
      throw new Error(`amap ${urlPathOrFull}: missing route`);
    }
    const paths: Object[] = asArray(routeObj['paths']);
    if (paths.length === 0) {
      throw new Error(`amap ${urlPathOrFull}: empty paths`);
    }
    const firstPath: Record<string, Object> | null = asObject(paths[0]);
    if (firstPath === null) {
      throw new Error(`amap ${urlPathOrFull}: bad path`);
    }
    const durationSec: number = asNumber(firstPath['duration'], 0);
    const steps: Object[] = asArray(firstPath['steps']);
    const stepPolys: GeoPoint[][] = [];
    for (let i = 0; i < steps.length; i++) {
      const step: Record<string, Object> | null = asObject(steps[i]);
      if (step === null) {
        continue;
      }
      const polyStr: string = asString(step['polyline'], '');
      const decoded: GeoPoint[] = decodeAmapPolyline(polyStr);
      if (decoded.length > 0) {
        stepPolys.push(decoded);
      }
    }
    let polyline: GeoPoint[] = mergePolylines(stepPolys);
    polyline = ensureEndpoints(polyline, from, to);
    const out: PassengerPathResult = new PassengerPathResult();
    out.etaMin = durationSec > 0 ? durationSec / 60 : 0;
    out.polyline = polyline;
    out.dataSource = DATA_LIVE;
    return out;
  }

  private async directionTransit(from: GeoPoint, to: GeoPoint, city: string): Promise<PassengerPathResult> {
    const cityName: string = city.trim().length > 0 ? city.trim() : '全国';
    const query: string = encodeQuery([
      `key=${urlEncode(this.key)}`,
      `origin=${urlEncode(lonLatParam(from))}`,
      `destination=${urlEncode(lonLatParam(to))}`,
      `city=${urlEncode(cityName)}`,
      'strategy=0',
      'nightflag=0'
    ]);
    const root: Record<string, Object> = await this.getJson(`${AMAP_BASE}/direction/transit/integrated?${query}`);
    this.assertStatus(root, 'transit');
    const routeObj: Record<string, Object> | null = asObject(root['route']);
    if (routeObj === null) {
      throw new Error('amap transit: missing route');
    }
    const transits: Object[] = asArray(routeObj['transits']);
    if (transits.length === 0) {
      throw new Error('amap transit: empty transits');
    }
    const first: Record<string, Object> | null = asObject(transits[0]);
    if (first === null) {
      throw new Error('amap transit: bad transit');
    }
    const durationSec: number = asNumber(first['duration'], 0);
    const segments: Object[] = asArray(first['segments']);
    const stepPolys: GeoPoint[][] = [];
    for (let s = 0; s < segments.length; s++) {
      const seg: Record<string, Object> | null = asObject(segments[s]);
      if (seg === null) {
        continue;
      }
      // walking / bus / railway may carry polyline
      this.collectTransitPolys(seg, stepPolys);
    }
    let polyline: GeoPoint[] = mergePolylines(stepPolys);
    if (polyline.length < 2) {
      polyline = ensureEndpoints([], from, to);
    } else {
      polyline = ensureEndpoints(polyline, from, to);
    }
    const out: PassengerPathResult = new PassengerPathResult();
    out.etaMin = durationSec > 0 ? durationSec / 60 : 0;
    out.polyline = polyline;
    out.dataSource = DATA_LIVE;
    return out;
  }

  private collectTransitPolys(seg: Record<string, Object>, out: GeoPoint[][]): void {
    const keys: string[] = ['walking', 'bus', 'railway', 'taxi'];
    for (let k = 0; k < keys.length; k++) {
      const node: Record<string, Object> | null = asObject(seg[keys[k]]);
      if (node === null) {
        continue;
      }
      // bus has buslines[]
      const buslines: Object[] = asArray(node['buslines']);
      if (buslines.length > 0) {
        for (let b = 0; b < buslines.length; b++) {
          const line: Record<string, Object> | null = asObject(buslines[b]);
          if (line === null) {
            continue;
          }
          const poly: string = asString(line['polyline'], '');
          const decoded: GeoPoint[] = decodeAmapPolyline(poly);
          if (decoded.length > 0) {
            out.push(decoded);
          }
        }
      }
      const polyDirect: string = asString(node['polyline'], '');
      if (polyDirect.length > 0) {
        const decoded2: GeoPoint[] = decodeAmapPolyline(polyDirect);
        if (decoded2.length > 0) {
          out.push(decoded2);
        }
      }
      const steps: Object[] = asArray(node['steps']);
      for (let i = 0; i < steps.length; i++) {
        const step: Record<string, Object> | null = asObject(steps[i]);
        if (step === null) {
          continue;
        }
        const poly: string = asString(step['polyline'], '');
        const decoded: GeoPoint[] = decodeAmapPolyline(poly);
        if (decoded.length > 0) {
          out.push(decoded);
        }
      }
    }
  }

  private assertStatus(root: Record<string, Object>, tag: string): void {
    const status: string = asString(root['status'], '');
    if (status === '1') {
      return;
    }
    const info: string = asString(root['info'], 'unknown');
    const infocode: string = asString(root['infocode'], '');
    throw new Error(`amap ${tag}: status=${status} info=${info} code=${infocode}`);
  }

  private async getJson(url: string): Promise<Record<string, Object>> {
    if (this.key.length === 0) {
      throw new Error('amap: empty key');
    }
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {};
      header['Accept'] = 'application/json';
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: this.timeoutMs,
        readTimeout: this.timeoutMs
      });
      const raw: string = typeof response.result === 'string' ? response.result as string : `${response.result}`;
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const snippet: string = raw.length > 160 ? raw.substring(0, 160) + '…' : raw;
        throw new Error(`amap HTTP ${response.responseCode}: ${snippet}`);
      }
      let parsed: Object;
      try {
        parsed = JSON.parse(raw) as Object;
      } catch (e) {
        const _ignored: Object = e as Object;
        throw new Error('amap: invalid JSON');
      }
      const obj: Record<string, Object> | null = asObject(parsed);
      if (obj === null) {
        throw new Error('amap: non-object JSON');
      }
      return obj;
    } finally {
      try {
        httpRequest.destroy();
      } catch (e) {
        const _ignored: Object = e as Object;
      }
    }
  }
}

/** Safe debug label — never includes key. */
export function amapKeyConfigured(key: string): boolean {
  return key.trim().length > 0;
}

export function amapDebugLabel(key: string): string {
  return amapKeyConfigured(key) ? 'AMap Web 已配置' : 'AMap Web 未配置';
}
