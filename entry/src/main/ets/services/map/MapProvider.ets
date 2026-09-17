/**
 * Map / routing provider surface.
 *
 * Hybrid:
 *  - forceEstimate=true  → force EstimateMapProvider (stage-safe)
 *  - mapWebKey present  → AmapWebMapProvider with estimate fallback
 *  - else               → estimate only
 *
 * dataSource is honest: live | live_with_fallback | estimate
 * (per-call fallback is marked live_with_fallback; full live only when AMap succeeds).
 */

import {
  AnalysisProviders,
  DrivingRouteResult,
  PassengerPathResult,
  runAnalysis
} from '../../domain/RunAnalysis';
import { defaultEngineConfig, EngineConfig } from '../../domain/EngineConfig';
import {
  DATA_ESTIMATE,
  DATA_LIVE,
  DATA_LIVE_FALLBACK,
  DataSource,
  GeoPoint,
  MobilityMode,
  NamedPoint,
  RecommendationSet,
  Scenario
} from '../../domain/Models';
import {
  buildStraightDrivingRoute,
  estimatePassengerPath,
  PassengerPathEstimate,
  StraightRouteBuild
} from '../../domain/Estimate';
import { AmapWebMapProvider, PoiHit } from './AmapWebMapProvider';

export interface MapProvider {
  getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult>;

  getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string,
    preferMetro?: boolean
  ): Promise<PassengerPathResult>;

  /** Best-effort place label; estimate returns lat,lon text. */
  reverseGeocode(point: GeoPoint): Promise<string>;

  /** Best-effort POI name list; estimate returns empty (no live index). */
  searchPoi(query: string, nearLon: number, nearLat: number, hasNear: boolean): Promise<string[]>;
  getRailStations(near: GeoPoint, radiusM: number): Promise<NamedPoint[]>;
  lookupPickupLandmark(point: GeoPoint): Promise<string>;
}

/** Optional rich POI search for UI pick. */
export interface PoiSearchCapable {
  searchPoiDetailed(
    query: string,
    nearLon: number,
    nearLat: number,
    hasNear: boolean,
    city: string
  ): Promise<PoiHit[]>;
}

export class EstimateMapProvider implements MapProvider {
  async getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> {
    const built: StraightRouteBuild = buildStraightDrivingRoute(from, to);
    const out: DrivingRouteResult = new DrivingRouteResult();
    out.polyline = built.polyline;
    out.route = built.route;
    out.dataSource = DATA_ESTIMATE;
    return out;
  }

  async getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    _city: string,
    _preferMetro: boolean = false
  ): Promise<PassengerPathResult> {
    const path: PassengerPathEstimate = estimatePassengerPath(mode, from, to);
    const out: PassengerPathResult = new PassengerPathResult();
    out.etaMin = path.etaMin;
    out.polyline = path.polyline;
    out.dataSource = DATA_ESTIMATE;
    return out;
  }

  async reverseGeocode(point: GeoPoint): Promise<string> {
    return `${point.lat.toFixed(5)}, ${point.lon.toFixed(5)}`;
  }

  async searchPoi(_query: string, _nearLon: number, _nearLat: number, _hasNear: boolean): Promise<string[]> {
    return [];
  }

  async getRailStations(_near: GeoPoint, _radiusM: number): Promise<NamedPoint[]> {
    return [];
  }

  async lookupPickupLandmark(_point: GeoPoint): Promise<string> {
    return '';
  }
}

export class HybridMapProvider implements MapProvider, PoiSearchCapable {
  private estimate: EstimateMapProvider = new EstimateMapProvider();
  private live: AmapWebMapProvider | null = null;
  private forceEstimate: boolean = false;

  constructor(mapWebKey: string = '', forceEstimate: boolean = false) {
    this.forceEstimate = forceEstimate;
    const key: string = mapWebKey.trim();
    if (!forceEstimate && key.length > 0) {
      this.live = new AmapWebMapProvider(key);
    } else {
      this.live = null;
    }
  }

  isLiveEnabled(): boolean {
    return this.live !== null;
  }

  async getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> {
    if (this.live === null) {
      return this.estimate.getDrivingRoute(from, to);
    }
    try {
      return await this.live.getDrivingRoute(from, to);
    } catch (e) {
      const _ignored: Object = e as Object;
      const fallback: DrivingRouteResult = await this.estimate.getDrivingRoute(from, to);
      fallback.dataSource = DATA_LIVE_FALLBACK;
      return fallback;
    }
  }

  async getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string,
    preferMetro: boolean = false
  ): Promise<PassengerPathResult> {
    if (this.live === null) {
      return this.estimate.getPassengerPath(mode, from, to, city, preferMetro);
    }
    try {
      return await this.live.getPassengerPath(mode, from, to, city, preferMetro);
    } catch (e) {
      const _ignored: Object = e as Object;
      const fallback: PassengerPathResult = await this.estimate.getPassengerPath(mode, from, to, city, preferMetro);
      fallback.dataSource = DATA_LIVE_FALLBACK;
      return fallback;
    }
  }

  async reverseGeocode(point: GeoPoint): Promise<string> {
    if (this.live === null) {
      return this.estimate.reverseGeocode(point);
    }
    try {
      return await this.live.reverseGeocode(point);
    } catch (e) {
      const _ignored: Object = e as Object;
      return this.estimate.reverseGeocode(point);
    }
  }

  async searchPoi(query: string, nearLon: number, nearLat: number, hasNear: boolean): Promise<string[]> {
    if (this.live === null) {
      return this.estimate.searchPoi(query, nearLon, nearLat, hasNear);
    }
    try {
      return await this.live.searchPoi(query, nearLon, nearLat, hasNear);
    } catch (e) {
      const _ignored: Object = e as Object;
      return this.estimate.searchPoi(query, nearLon, nearLat, hasNear);
    }
  }

  async getRailStations(near: GeoPoint, radiusM: number): Promise<NamedPoint[]> {
    if (this.live === null) return [];
    try {
      return await this.live.getRailStations(near, radiusM);
    } catch (_) {
      return [];
    }
  }

  async lookupPickupLandmark(point: GeoPoint): Promise<string> {
    if (this.live === null) {
      return '';
    }
    try {
      return await this.live.lookupPickupLandmark(point);
    } catch (e) {
      const _ignored: Object = e as Object;
      return '';
    }
  }

  async searchPoiDetailed(
    query: string,
    nearLon: number,
    nearLat: number,
    hasNear: boolean,
    city: string
  ): Promise<PoiHit[]> {
    if (this.live === null) {
      return [];
    }
    try {
      return await this.live.searchPoiDetailed(query, nearLon, nearLat, hasNear, city);
    } catch (e) {
      const _ignored: Object = e as Object;
      return [];
    }
  }
}

class MapProviderAsAnalysis implements AnalysisProviders {
  private provider: MapProvider;

  constructor(provider: MapProvider) {
    this.provider = provider;
  }

  async getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> {
    return this.provider.getDrivingRoute(from, to);
  }

  async getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string,
    preferMetro: boolean = false
  ): Promise<PassengerPathResult> {
    return this.provider.getPassengerPath(mode, from, to, city, preferMetro);
  }

  async getRailStations(near: GeoPoint, radiusM: number): Promise<NamedPoint[]> {
    return this.provider.getRailStations(near, radiusM);
  }

  async lookupPickupLandmark(point: GeoPoint): Promise<string> {
    return this.provider.lookupPickupLandmark(point);
  }
}

export class PlanningService {
  /**
   * @param mapWebKey AMap Web service key (preferences only)
   * @param forceEstimate when true (tests), ignore key and use estimate
   */
  static createProvider(mapWebKey: string, forceEstimate: boolean = false): MapProvider {
    if (forceEstimate) {
      return new HybridMapProvider('', true);
    }
    return new HybridMapProvider(mapWebKey, false);
  }


  static async plan(
    scenario: Scenario,
    provider: MapProvider,
    cfg: EngineConfig = defaultEngineConfig()
  ): Promise<RecommendationSet> {
    const bridge: MapProviderAsAnalysis = new MapProviderAsAnalysis(provider);
    return runAnalysis(scenario, bridge, cfg, new Date().toISOString());
  }

  static describeProvider(mapWebKey: string, forceEstimate: boolean): string {
    if (forceEstimate) {
      return '离线估算';
    }
    if (mapWebKey.trim().length > 0) {
      return '实时路线 · 自动离线回退';
    }
    return '离线估算';
  }

  static mergeDataSourceLabel(source: DataSource): string {
    if (source === DATA_LIVE) {
      return '实时';
    }
    if (source === DATA_LIVE_FALLBACK) {
      return '实时+估算';
    }
    return '估算';
  }
}
