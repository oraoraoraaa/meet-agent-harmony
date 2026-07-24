import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';

export type LocationPermissionState = 'unknown' | 'granted' | 'denied' | 'unavailable';

export interface LocationSnapshot {
  permission: LocationPermissionState;
  message: string;
  lon?: number;
  lat?: number;
}

const LOCATION_PERMISSIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION'
];

/**
 * One-shot location helper for Phase 0 (no continuous tracking).
 */
export class LocationService {
  static async ensurePermission(context: common.UIAbilityContext): Promise<LocationPermissionState> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, LOCATION_PERMISSIONS);
      const authResults = result.authResults;
      if (authResults === undefined || authResults.length === 0) {
        return 'denied';
      }
      for (let i = 0; i < authResults.length; i++) {
        if (authResults[i] !== 0) {
          return 'denied';
        }
      }
      return 'granted';
    } catch (_err) {
      return 'unavailable';
    }
  }

  static async readOnce(context: common.UIAbilityContext): Promise<LocationSnapshot> {
    const permission = await LocationService.ensurePermission(context);
    if (permission !== 'granted') {
      return {
        permission,
        message: permission === 'denied'
          ? '定位权限未授予 — 仍可手动选点规划'
          : '定位能力不可用 — 仍可手动选点规划'
      };
    }

    try {
      // Default current-location request (API-stable minimal shape).
      const location = await geoLocationManager.getCurrentLocation();
      return {
        permission: 'granted',
        message: `已定位 ${location.latitude.toFixed(5)}, ${location.longitude.toFixed(5)}`,
        lat: location.latitude,
        lon: location.longitude
      };
    } catch (err) {
      const be = err as BusinessError;
      const code = be !== undefined && be.code !== undefined ? `${be.code}` : 'err';
      return {
        permission: 'granted',
        message: `定位失败 (${code}) — 可改用手动选点`
      };
    }
  }
}
