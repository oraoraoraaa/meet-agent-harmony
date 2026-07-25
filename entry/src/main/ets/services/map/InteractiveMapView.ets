/**
 * Interactive map stage: AMap JS via Web when mapWebKey present;
 * offline schematic canvas (same HTML) otherwise.
 * Picks: meetagent://pick | meetagent://choose
 */

import { webview } from '@kit.ArkWeb';
import { AppTheme } from '../../common/AppTheme';
import { GeoPoint } from '../../domain/Models';
import { buildInteractiveMapHtml, MapViewMarkers } from './AmapMapHtml';

export class MapPickEvent {
  role: string = 'passenger';
  lon: number = 0;
  lat: number = 0;
  name: string = '';
}

/** Free search/map-tap result — host asks how to assign. */
export class MapChooseEvent {
  lon: number = 0;
  lat: number = 0;
  name: string = '';
}

@Component
export struct InteractiveMapView {
  @Prop mapWebKey: string = '';
  @Prop pickRole: string = 'passenger';
  @Prop @Watch('onMarkersChanged') driverLon: number = 108.8905;
  @Prop @Watch('onMarkersChanged') driverLat: number = 34.2324;
  @Prop @Watch('onMarkersChanged') hasDriver: boolean = true;
  @Prop @Watch('onMarkersChanged') passengerLon: number = 108.9465;
  @Prop @Watch('onMarkersChanged') passengerLat: number = 34.2610;
  @Prop @Watch('onMarkersChanged') hasPassenger: boolean = true;
  @Prop centerLon: number = 108.94;
  @Prop centerLat: number = 34.25;
  @Prop zoom: number = 13;
  @Prop title: string = '地图';
  @Prop driverLine: GeoPoint[] = [];
  @Prop passengerLine: GeoPoint[] = [];
  /** Bump to force Web reload after external state change. */
  @Prop @Watch('onReloadTokenChanged') reloadToken: number = 0;
  /** Live traffic layer (AMap TileLayer.Traffic). */
  @Prop showTraffic: boolean = true;
  /** In-map chips to switch driver/passenger pick target. */
  @Prop allowRoleSwitch: boolean = true;
  /**
   * true = home chrome (search / 路况 / 居中).
   * false = result preview: pan+pinch only, no POI selection UI.
   */
  @Prop showChrome: boolean = true;
  onPick?: (ev: MapPickEvent) => void;
  /** Fired when user picks a POI/map point without role (search-first flow). */
  onChoose?: (ev: MapChooseEvent) => void;

  private controller: webview.WebviewController = new webview.WebviewController();
  @State private status: string = '初始化地图…';
  @State private attached: boolean = false;
  @State private pageReady: boolean = false;
  private lastLoadedToken: number = -999;
  private markerSyncPending: boolean = false;

  aboutToAppear(): void {
    // load happens onControllerAttached
  }

  onReloadTokenChanged(): void {
    this.pageReady = false;
    this.markerSyncPending = false;
    if (this.attached) {
      this.reloadMap();
    }
  }

  onMarkersChanged(): void {
    // Prop updates alone do not refresh Web content — full reload with new pins.
    if (this.attached) {
      this.reloadMap();
    } else {
      this.markerSyncPending = true;
    }
  }

  private polyJson(line: GeoPoint[]): string {
    if (line.length === 0) {
      return '[]';
    }
    const maxPts: number = 64;
    const step: number = line.length > maxPts ? Math.ceil(line.length / maxPts) : 1;
    let s: string = '[';
    let first: boolean = true;
    for (let i = 0; i < line.length; i += step) {
      if (!first) {
        s += ',';
      }
      first = false;
      s += '[' + line[i].lon + ',' + line[i].lat + ']';
    }
    const last: GeoPoint = line[line.length - 1];
    const lastPair: string = '[' + last.lon + ',' + last.lat + ']';
    if (s.indexOf(lastPair) < 0) {
      if (s !== '[') {
        s += ',';
      }
      s += lastPair;
    }
    s += ']';
    return s;
  }

  private buildHtml(): string {
    const m: MapViewMarkers = new MapViewMarkers();
    m.mapWebKey = this.mapWebKey;
    // Result maps force pickRole none so taps never assign POIs.
    m.pickRole = this.showChrome ? this.pickRole : 'none';
    m.driverLon = this.driverLon;
    m.driverLat = this.driverLat;
    m.hasDriver = this.hasDriver;
    m.passengerLon = this.passengerLon;
    m.passengerLat = this.passengerLat;
    m.hasPassenger = this.hasPassenger;
    m.centerLon = this.centerLon;
    m.centerLat = this.centerLat;
    m.zoom = this.zoom;
    m.title = this.title;
    m.driverPolyJson = this.polyJson(this.driverLine);
    m.passengerPolyJson = this.polyJson(this.passengerLine);
    m.showTraffic = this.showTraffic;
    m.allowRoleSwitch = this.showChrome && this.allowRoleSwitch && this.pickRole !== 'none';
    m.showChrome = this.showChrome;
    return buildInteractiveMapHtml(m);
  }

  private reloadMap(): void {
    if (!this.attached) {
      return;
    }
    this.lastLoadedToken = this.reloadToken;
    this.pageReady = false;
    this.status = this.mapWebKey.trim().length > 0
      ? (this.showChrome ? '加载高德地图…' : '')
      : (this.showChrome ? '示意地图（无 Web Key / 演示）' : '');
    const html: string = this.buildHtml();
    try {
      this.controller.loadData(
        html,
        'text/html',
        'UTF-8',
        'https://local.meetagent/map',
        'https://local.meetagent/'
      );
    } catch (e) {
      const _ignored: Object = e as Object;
      try {
        const encoded: string = encodeURIComponent(html);
        this.controller.loadUrl('data:text/html;charset=utf-8,' + encoded);
      } catch (e2) {
        const _ignored2: Object = e2 as Object;
        this.status = '地图加载失败';
      }
    }
  }

  private handleUrl(url: string): boolean {
    if (url.indexOf('meetagent://choose') >= 0) {
      return this.handleChooseUrl(url);
    }
    if (url.indexOf('meetagent://pick') < 0) {
      return false;
    }
    const q: number = url.indexOf('?');
    if (q < 0) {
      return true;
    }
    const query: string = url.substring(q + 1);
    const parts: string[] = query.split('&');
    let role: string = this.pickRole;
    let lon: number = 0;
    let lat: number = 0;
    let name: string = '';
    for (let i = 0; i < parts.length; i++) {
      const eq: number = parts[i].indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const k: string = parts[i].substring(0, eq);
      let v: string = parts[i].substring(eq + 1);
      try {
        v = decodeURIComponent(v);
      } catch (e) {
        const _ignored: Object = e as Object;
      }
      if (k === 'role') {
        role = v;
      } else if (k === 'lon') {
        lon = Number(v);
      } else if (k === 'lat') {
        lat = Number(v);
      } else if (k === 'name') {
        name = v;
      }
    }
    if (isNaN(lon) || isNaN(lat)) {
      return true;
    }
    if (this.onChoose && (role.length === 0 || role === 'none')) {
      const ce: MapChooseEvent = new MapChooseEvent();
      ce.lon = lon;
      ce.lat = lat;
      ce.name = name;
      this.status = `已选地点 ${lat.toFixed(5)}, ${lon.toFixed(5)}`;
      this.onChoose(ce);
      return true;
    }
    const ev: MapPickEvent = new MapPickEvent();
    ev.role = role;
    ev.lon = lon;
    ev.lat = lat;
    ev.name = name;
    this.status = `已选 ${lat.toFixed(5)}, ${lon.toFixed(5)}`;
    if (this.onPick) {
      this.onPick(ev);
    }
    return true;
  }

  private handleChooseUrl(url: string): boolean {
    const q: number = url.indexOf('?');
    if (q < 0) {
      return true;
    }
    const query: string = url.substring(q + 1);
    const parts: string[] = query.split('&');
    let lon: number = 0;
    let lat: number = 0;
    let name: string = '';
    for (let i = 0; i < parts.length; i++) {
      const eq: number = parts[i].indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const k: string = parts[i].substring(0, eq);
      let v: string = parts[i].substring(eq + 1);
      try {
        v = decodeURIComponent(v);
      } catch (e) {
        const _ignored: Object = e as Object;
      }
      if (k === 'lon') {
        lon = Number(v);
      } else if (k === 'lat') {
        lat = Number(v);
      } else if (k === 'name') {
        name = v;
      }
    }
    if (isNaN(lon) || isNaN(lat)) {
      return true;
    }
    const ce: MapChooseEvent = new MapChooseEvent();
    ce.lon = lon;
    ce.lat = lat;
    ce.name = name;
    this.status = `已选地点 ${lat.toFixed(5)}, ${lon.toFixed(5)}`;
    if (this.onChoose) {
      this.onChoose(ce);
    } else if (this.onPick) {
      const ev: MapPickEvent = new MapPickEvent();
      ev.role = this.pickRole === 'driver' ? 'driver' : 'passenger';
      ev.lon = lon;
      ev.lat = lat;
      ev.name = name;
      this.onPick(ev);
    }
    return true;
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Web({ src: 'about:blank', controller: this.controller })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .zoomAccess(true)
        .onControllerAttached(() => {
          this.attached = true;
          this.reloadMap();
          // Layout may still be settling; reload once more so first paint isn't blank.
          setTimeout(() => {
            if (this.attached) {
              this.reloadMap();
            }
          }, 100);
        })
        .onPageEnd(() => {
          if (this.reloadToken !== this.lastLoadedToken) {
            this.reloadMap();
            return;
          }
          this.pageReady = true;
          this.status = !this.showChrome
            ? ''
            : (this.mapWebKey.trim().length > 0
              ? '地图就绪 · 搜索/点选后选择用途'
              : '示意地图就绪 · 点选后选择用途');
          if (this.markerSyncPending) {
            this.markerSyncPending = false;
            this.reloadMap();
          }
        })
        .onLoadIntercept((event): boolean => {
          try {
            const url: string = event.data.getRequestUrl();
            if (this.handleUrl(url)) {
              return true;
            }
          } catch (e) {
            const _ignored: Object = e as Object;
          }
          return false;
        })
        .borderRadius(16)
        .clip(true)

      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(10)
          .fontColor(AppTheme.inkMuted)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#99000000')
          .borderRadius(8)
          .margin({ left: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .backgroundColor(AppTheme.mapPanel)
    .onAppear(() => {
      if (this.attached && this.reloadToken !== this.lastLoadedToken) {
        this.reloadMap();
      }
    })
  }
}
