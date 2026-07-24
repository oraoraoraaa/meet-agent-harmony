/**
 * Map / routing provider surface.
 *
 * Runtime today: estimate-only (Mode C). HybridMapProvider keeps mapWebKey so
 * a later AMap Web HTTP branch can land without changing PlanningService callers.
 * Live REST is intentionally deferred (not a missing Phase 2 dependency).
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
  GeoPoint,
  MobilityMode,
  RecommendationSet,
  Scenario
} from '../../domain/Models';
import {
  buildStraightDrivingRoute,
  estimatePassengerPath,
  PassengerPathEstimate,
  StraightRouteBuild
} from '../../domain/Estimate';

export interface MapProvider {
  getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult>;

  getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string
  ): Promise<PassengerPathResult>;

  /** Best-effort place label; estimate returns lat,lon text. */
  reverseGeocode(point: GeoPoint): Promise<string>;

  /** Best-effort POI search; estimate returns empty (no live index). */
  searchPoi(query: string, nearLon: number, nearLat: number, hasNear: boolean): Promise<string[]>;
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
    _city: string
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
}

export class HybridMapProvider implements MapProvider {
  private estimate: EstimateMapProvider = new EstimateMapProvider();
  private mapWebKey: string = '';

  constructor(mapWebKey: string = '') {
    this.mapWebKey = mapWebKey.trim();
    // mapWebKey reserved for live AMap REST (still deferred; estimate path only).
    void this.mapWebKey;
  }

  async getDrivingRoute(from: GeoPoint, to: GeoPoint): Promise<DrivingRouteResult> {
    return this.estimate.getDrivingRoute(from, to);
  }

  async getPassengerPath(
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: string
  ): Promise<PassengerPathResult> {
    return this.estimate.getPassengerPath(mode, from, to, city);
  }

  async reverseGeocode(point: GeoPoint): Promise<string> {
    return this.estimate.reverseGeocode(point);
  }

  async searchPoi(query: string, nearLon: number, nearLat: number, hasNear: boolean): Promise<string[]> {
    return this.estimate.searchPoi(query, nearLon, nearLat, hasNear);
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
    city: string
  ): Promise<PassengerPathResult> {
    return this.provider.getPassengerPath(mode, from, to, city);
  }
}

export class PlanningService {
  static createProvider(mapWebKey: string): MapProvider {
    return new HybridMapProvider(mapWebKey);
  }

  static async plan(
    scenario: Scenario,
    provider: MapProvider,
    cfg: EngineConfig = defaultEngineConfig()
  ): Promise<RecommendationSet> {
    const bridge: MapProviderAsAnalysis = new MapProviderAsAnalysis(provider);
    return runAnalysis(scenario, bridge, cfg, new Date().toISOString());
  }
}
