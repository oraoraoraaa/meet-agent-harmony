import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { map, mapCommon } from '@kit.MapKit';
import { GeoPoint } from '../../domain/Models';

/** Foreground, one-shot fix. Native GPS coordinates must be converted before using AMap. */
export class LocationService {
  static async readOnce(context: common.UIAbilityContext): Promise<GeoPoint> {
    const permissions: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissions);
    if (result.authResults.length === 0 || result.authResults[0] !== 0) {
      throw new Error('未获得定位权限，请搜索地点或在地图选点');
    }
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      maxAccuracy: 0,
      timeoutMs: 12000
    };
    const fix: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
    if (!Number.isFinite(fix.longitude) || !Number.isFinite(fix.latitude) ||
      Math.abs(fix.longitude) > 180 || Math.abs(fix.latitude) > 90) {
      throw new Error('定位数据不可用');
    }
    const wgs: mapCommon.LatLng = { latitude: fix.latitude, longitude: fix.longitude };
    const gcj: mapCommon.LatLng = map.convertCoordinateSync(
      mapCommon.CoordinateType.WGS84, mapCommon.CoordinateType.GCJ02, wgs);
    return new GeoPoint(gcj.longitude, gcj.latitude);
  }
}
