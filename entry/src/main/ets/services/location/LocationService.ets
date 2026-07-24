import {
  abilityAccessCtrl,
  common,
  PermissionRequestResult,
  Permissions
} from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';

export type LocationPermissionState = 'unknown' | 'granted' | 'denied' | 'unavailable';

export interface LocationSnapshot {
  permission: LocationPermissionState;
  message: string;
  lon?: number;
  lat?: number;
}

const LOCATION_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION'
];

/**
 * Typed one-shot request (ArkTS disallows untyped object literals).
 * Emulator 3301100: location service has no fix — enable location simulation.
 */
class OnceLocationRequest {
  priority: geoLocationManager.LocationRequestPriority =
    geoLocationManager.LocationRequestPriority.FIRST_FIX;
  scenario: geoLocationManager.LocationRequestScenario =
    geoLocationManager.LocationRequestScenario.UNSET;
  maxAccuracy: number = 100;
  timeoutMs: number = 15000;
}

/**
 * One-shot location helper (no continuous tracking).
 */
export class LocationService {
  static async ensurePermission(context: common.UIAbilityContext): Promise<LocationPermissionState> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, LOCATION_PERMISSIONS);
      const authResults: Array<number> = result.authResults;
      if (authResults.length === 0) {
        return 'denied';
      }
      for (let i = 0; i < authResults.length; i++) {
        if (authResults[i] !== 0) {
          return 'denied';
        }
      }
      return 'granted';
    } catch (e) {
      const _ignored: Object = e as Object;
      return 'unavailable';
    }
  }

  private static describeError(code: string): string {
    // 3301100: common “no fix / service not ready” on emulators even when permission granted.
    if (code === '3301100' || code === '3301200' || code === '3301000') {
      return '定位服务无可用坐标（模拟器请开位置模拟）— 可改用手动选点';
    }
    if (code === '201' || code === '202') {
      return '定位权限不足 — 请在系统设置中允许位置信息';
    }
    return `定位失败 (${code}) — 可改用手动选点`;
  }

  private static fromLocation(location: geoLocationManager.Location): LocationSnapshot {
    const lat: number = location.latitude;
    const lon: number = location.longitude;
    return {
      permission: 'granted',
      message: `已定位 ${lat.toFixed(5)}, ${lon.toFixed(5)}`,
      lat: lat,
      lon: lon
    };
  }

  private static errorCodeFrom(e: Object): string {
    const be: BusinessError = e as BusinessError;
    if (be !== null && be !== undefined && be.code !== undefined) {
      return `${be.code}`;
    }
    return 'err';
  }

  static async readOnce(context: common.UIAbilityContext): Promise<LocationSnapshot> {
    const permission: LocationPermissionState = await LocationService.ensurePermission(context);
    if (permission !== 'granted') {
      const message: string = permission === 'denied'
        ? '定位权限未授予 — 仍可手动选点规划'
        : '定位能力不可用 — 仍可手动选点规划';
      return {
        permission: permission,
        message: message
      };
    }

    let lastCode: string = 'err';
    try {
      const req: OnceLocationRequest = new OnceLocationRequest();
      const location: geoLocationManager.Location =
        await geoLocationManager.getCurrentLocation(req);
      return LocationService.fromLocation(location);
    } catch (e1) {
      lastCode = LocationService.errorCodeFrom(e1 as Object);
    }

    // Fallback: no-arg API (some builds only implement this form).
    try {
      const location2: geoLocationManager.Location = await geoLocationManager.getCurrentLocation();
      return LocationService.fromLocation(location2);
    } catch (e2) {
      lastCode = LocationService.errorCodeFrom(e2 as Object);
      return {
        permission: 'granted',
        message: LocationService.describeError(lastCode)
      };
    }
  }
}
