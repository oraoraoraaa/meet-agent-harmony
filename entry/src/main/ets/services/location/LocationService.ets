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
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: abilityAccessCtrl.PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, LOCATION_PERMISSIONS);
      const authResults: number[] = result.authResults;
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

    try {
      const location: geoLocationManager.Location = await geoLocationManager.getCurrentLocation();
      const lat: number = location.latitude;
      const lon: number = location.longitude;
      return {
        permission: 'granted',
        message: `已定位 ${lat.toFixed(5)}, ${lon.toFixed(5)}`,
        lat: lat,
        lon: lon
      };
    } catch (e) {
      let code: string = 'err';
      const be: BusinessError = e as BusinessError;
      if (be !== null && be !== undefined && be.code !== undefined) {
        code = `${be.code}`;
      }
      return {
        permission: 'granted',
        message: `定位失败 (${code}) — 可改用手动选点`
      };
    }
  }
}
