/**
 * Open locked meeting point in Maps.
 *
 * Schemes (Phase 3 notes):
 * 1. Preferred app from Settings (mapApp):
 *    - amap:   androidamap://viewMap?sourceApplication=MeetAgent&lat={lat}&lon={lon}&poiname={name}
 *    - baidu:  baidumap://map/marker?location={lat},{lon}&title={name}&coord_type=gcj02
 *    - apple:  http://maps.apple.com/?ll={lat},{lon}&q={name}
 *    - browser / fallback:
 *              https://uri.amap.com/marker?position={lon},{lat}&name={name}
 *
 * Coordinates are GCJ-02 end-to-end. We never invent coords.
 * Opens via UIAbilityContext.startAbility with action viewData + uri.
 */

import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  MAP_APP_AMAP,
  MAP_APP_APPLE,
  MAP_APP_BAIDU,
  MAP_APP_BROWSER,
  MapAppChoice
} from '../../common/AppSettings';

export {
  MAP_APP_AMAP,
  MAP_APP_APPLE,
  MAP_APP_BAIDU,
  MAP_APP_BROWSER
};

function encodeUriComponentSafe(raw: string): string {
  let out: string = '';
  for (let i = 0; i < raw.length; i++) {
    const ch: string = raw.charAt(i);
    const code: number = raw.charCodeAt(i);
    if (
      (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a) ||
      ch === '-' ||
      ch === '_' ||
      ch === '.' ||
      ch === '~'
    ) {
      out += ch;
    } else if (ch === ' ') {
      out += '%20';
    } else if (ch === ',') {
      out += '%2C';
    } else if (code > 0x7f) {
      // CJK kept raw for web URLs; many system handlers accept UTF-8 path/query.
      out += ch;
    } else {
      const hex: string = code.toString(16).toUpperCase();
      out += '%' + (hex.length < 2 ? '0' + hex : hex);
    }
  }
  return out;
}

export function buildWebMapUrl(lon: number, lat: number, name: string): string {
  const label: string = name.length > 0 ? name : '会合点';
  return `https://uri.amap.com/marker?position=${lon},${lat}&name=${encodeUriComponentSafe(label)}`;
}

export function buildAppScheme(app: MapAppChoice, lon: number, lat: number, name: string): string {
  const label: string = name.length > 0 ? name : '会合点';
  const q: string = encodeUriComponentSafe(label);
  if (app === MAP_APP_AMAP) {
    return `androidamap://viewMap?sourceApplication=MeetAgent&poiname=${q}&lat=${lat}&lon=${lon}&dev=0`;
  }
  if (app === MAP_APP_BAIDU) {
    return `baidumap://map/marker?location=${lat},${lon}&title=${q}&content=${q}&coord_type=gcj02&src=MeetAgent`;
  }
  if (app === MAP_APP_APPLE) {
    return `http://maps.apple.com/?ll=${lat},${lon}&q=${q}`;
  }
  return buildWebMapUrl(lon, lat, name);
}

function normalizeMapApp(preferredApp: MapAppChoice): MapAppChoice {
  if (preferredApp === MAP_APP_AMAP) {
    return MAP_APP_AMAP;
  }
  if (preferredApp === MAP_APP_BAIDU) {
    return MAP_APP_BAIDU;
  }
  if (preferredApp === MAP_APP_APPLE) {
    return MAP_APP_APPLE;
  }
  return MAP_APP_BROWSER;
}

export class MapLinkService {
  static async openMeeting(
    context: common.UIAbilityContext,
    lon: number,
    lat: number,
    name: string,
    preferredApp: MapAppChoice
  ): Promise<void> {
    const app: MapAppChoice = normalizeMapApp(preferredApp);

    if (app === MAP_APP_BROWSER) {
      await MapLinkService.openUri(context, buildWebMapUrl(lon, lat, name), true);
      return;
    }

    const scheme: string = buildAppScheme(app, lon, lat, name);
    const ok: boolean = await MapLinkService.openUri(context, scheme, false);
    if (!ok) {
      const web: string = buildWebMapUrl(lon, lat, name);
      const webOk: boolean = await MapLinkService.openUri(context, web, true);
      if (!webOk) {
        promptAction.showToast({
          message: '无法打开地图，请手动搜索坐标',
          duration: 2400
        });
      } else {
        promptAction.showToast({
          message: '应用未安装，已打开网页地图',
          duration: 2000
        });
      }
    }
  }

  private static async openUri(
    context: common.UIAbilityContext,
    uri: string,
    showErrorToast: boolean
  ): Promise<boolean> {
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: uri
      };
      await context.startAbility(want);
      return true;
    } catch (e) {
      const errObj: Object = e as Object;
      if (showErrorToast) {
        promptAction.showToast({
          message: `打开失败：${errObj}`,
          duration: 2200
        });
      }
      return false;
    }
  }
}
