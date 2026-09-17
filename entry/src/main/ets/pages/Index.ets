import { LocationSearchSheet } from '../common/LocationSearchSheet';
import { LocationService } from '../services/location/LocationService';
import { AmapWebMapProvider, PoiHit } from '../services/map/AmapWebMapProvider';
import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
import { StageBackground } from '../common/GlassChrome';
import { BottomNavigation } from '../common/BottomNavigation';
import { AppSettings } from '../common/AppSettings';
import { SettingsStore } from '../services/settings/SettingsStore';
import { InteractiveMapView, MapPickEvent, MapChooseEvent } from '../services/map/InteractiveMapView';
import { PlanningService } from '../services/map/MapProvider';
import { GeoPoint } from '../domain/Models';
import { TripDraftStore } from '../services/session/TripDraftStore';

/** Map-first pickup selection with a compact planning sheet. */
@Entry
@Component
struct Index {
  @State searchOpen: boolean = false;
  @State searchDriver: boolean = true;
  @State locating: boolean = false;
  @State openingPlan: boolean = false;
  @State locationError: string = '';
  private disposed: boolean = false;
  private selectionRevision: number = 0;
  @State settings: AppSettings = new AppSettings();
  // Initial viewport is Xi’an; neither location is selected until the user chooses.
  @State driverLon: number = 108.8905;
  @State driverLat: number = 34.2324;
  @State hasDriver: boolean = false;
  @State passengerLon: number = 108.9465;
  @State passengerLat: number = 34.2610;
  @State hasPassenger: boolean = false;
  @State passengerName: string = '选择乘客位置';
  @State driverName: string = '选择司机出发地';
  @State mapToken: number = 0;
  /** Pending free-search / map-tap point awaiting assign. */
  @State assignOpen: boolean = false;
  @State pendingLon: number = 0;
  @State pendingLat: number = 0;
  @State pendingName: string = '';
  /** After assign, prefer centering map on this point. */
  @State focusLon: number = 108.94;
  @State focusLat: number = 34.25;
  @State hasFocus: boolean = false;

  aboutToAppear(): void {
    this.hydrateDraft();
  }

  onPageShow(): void {
    this.disposed = false;
    this.hydrateDraft();
    this.refreshSettings();
  }

  onPageHide(): void { this.disposed = true; }

  aboutToDisappear(): void { this.disposed = true; }

  onBackPress(): boolean {
    if (this.searchOpen) { this.searchOpen = false; return true; }
    if (this.assignOpen) { this.assignOpen = false; return true; }
    return false;
  }

  private hostContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private hydrateDraft(): void {
    const d = TripDraftStore.get();
    if (d.hasDriver) {
      this.driverLon = d.driverLon;
      this.driverLat = d.driverLat;
      this.hasDriver = true;
      if (d.driverName.length > 0) {
        this.driverName = d.driverName;
      }
    }
    if (d.hasPassenger) {
      this.passengerLon = d.passengerLon;
      this.passengerLat = d.passengerLat;
      this.hasPassenger = true;
      if (d.passengerName.length > 0) {
        this.passengerName = d.passengerName;
      }
    }
  }

  private persistDraft(): void {
    TripDraftStore.setDriver(this.driverLon, this.driverLat, this.driverName, this.hasDriver);
    TripDraftStore.setPassenger(this.passengerLon, this.passengerLat, this.passengerName, this.hasPassenger);
  }

  private mapKeyForView(): string {
    return this.settings.mapWebKey;
  }


  private async refreshSettings(): Promise<void> {
    try {
      const previousMapKey: string = this.mapKeyForView();
      this.settings = await SettingsStore.load(this.hostContext());
      if (previousMapKey !== this.mapKeyForView()) {
        this.mapToken = this.mapToken + 1;
      }
    } catch (e) {
      const _ignored: Object = e as Object;
      promptAction.showToast({ message: '暂时无法读取设置，已使用离线模式' });
    }
  }

  private onMapChoose(ev: MapChooseEvent): void {
    this.pendingLon = ev.lon;
    this.pendingLat = ev.lat;
    this.pendingName = ev.name.length > 0 ? ev.name : '地图选点';
    this.assignOpen = true;
  }

  private closeAssign(): void {
    this.assignOpen = false;
  }

  /** UI label: never show bare lat/lon. */
  private displayPlace(name: string): string {
    const n: string = name.trim();
    if (n === '当前位置') return n;
    if (n.length === 0 || n === '地图选点') {
      return '附近地点';
    }
    // Strip trailing " · lat, lon" if any legacy string
    const parts: string[] = n.split('·');
    if (parts.length >= 2) {
      const tail: string = parts[parts.length - 1].trim();
      if (tail.indexOf(',') >= 0) {
        const t0: string = tail.charAt(0);
        if (t0 >= '0' && t0 <= '9') {
          let head: string = parts[0].trim();
          for (let i = 1; i < parts.length - 1; i++) {
            head = `${head} · ${parts[i].trim()}`;
          }
          return head.length > 0 ? head : '附近地点';
        }
      }
    }
    if (this.looksLikeRawCoords(n)) {
      return '附近地点';
    }
    return n;
  }

  private looksLikeRawCoords(name: string): boolean {
    const n: string = name.trim();
    if (n.length === 0 || n === '地图选点' || n === '附近地点') {
      return true;
    }
    // "34.21, 108.90" style
    if (n.indexOf(',') > 0) {
      const a: string = n.split(',')[0].trim();
      const b: string = n.split(',')[1].trim();
      if (a.length > 0 && b.length > 0 && a.charAt(0) >= '0' && a.charAt(0) <= '9') {
        return true;
      }
    }
    return false;
  }

  private async resolvePlaceName(lon: number, lat: number, fallback: string): Promise<string> {
    const fb: string = fallback.trim();
    // Keep real POI search hits (not map-tap placeholder)
    if (!this.looksLikeRawCoords(fb) && fb !== '地图选点' && fb !== '当前位置') {
      const first: string = fb.length > 0 ? fb.charAt(0) : '';
      if (!(first >= '0' && first <= '9')) {
        return fb;
      }
    }
    try {
      const provider = PlanningService.createProvider(this.settings.mapWebKey, false);
      const label: string = await provider.reverseGeocode(new GeoPoint(lon, lat));
      if (label.trim().length > 0) {
        return label.trim();
      }
    } catch (e) {
      const _ignored: Object = e as Object;
    }
    return fb.length > 0 && fb !== '地图选点' ? fb : '附近地点';
  }

  private assignAsPassenger(): void {
    this.selectionRevision++;
    this.passengerLon = this.pendingLon;
    this.passengerLat = this.pendingLat;
    this.hasPassenger = true;
    this.passengerName = this.pendingName;
    this.focusLon = this.pendingLon;
    this.focusLat = this.pendingLat;
    this.hasFocus = true;
    this.assignOpen = false;
    this.mapToken = this.mapToken + 1;
    promptAction.showToast({ message: '已设为乘客位置', duration: 1400 });
    this.persistDraft();
    this.finalizePassengerLabel();
  }

  private assignAsDriver(): void {
    this.selectionRevision++;
    this.driverLon = this.pendingLon;
    this.driverLat = this.pendingLat;
    this.hasDriver = true;
    this.driverName = this.pendingName;
    this.focusLon = this.pendingLon;
    this.focusLat = this.pendingLat;
    this.hasFocus = true;
    this.assignOpen = false;
    this.mapToken = this.mapToken + 1;
    promptAction.showToast({ message: '已设为司机起点', duration: 1400 });
    this.persistDraft();
    this.finalizeDriverLabel();
  }

  private async finalizePassengerLabel(): Promise<void> {
    const lon: number = this.passengerLon;
    const lat: number = this.passengerLat;
    const label: string = await this.resolvePlaceName(
      lon,
      this.passengerLat,
      this.passengerName
    );
    if (lon !== this.passengerLon || lat !== this.passengerLat) return;
    this.passengerName = label;
    this.persistDraft();
  }

  private async finalizeDriverLabel(): Promise<void> {
    const lon: number = this.driverLon;
    const lat: number = this.driverLat;
    const label: string = await this.resolvePlaceName(
      lon,
      this.driverLat,
      this.driverName
    );
    if (lon !== this.driverLon || lat !== this.driverLat) return;
    this.driverName = label;
    this.persistDraft();
  }

  private onMapPick(ev: MapPickEvent): void {
    // Legacy direct pick path (still supported)
    if (ev.role === 'driver') {
      this.pendingLon = ev.lon;
      this.pendingLat = ev.lat;
      this.pendingName = ev.name.length > 0 ? ev.name : '地图选点';
      this.assignAsDriver();
    } else {
      this.pendingLon = ev.lon;
      this.pendingLat = ev.lat;
      this.pendingName = ev.name.length > 0 ? ev.name : '地图选点';
      this.assignAsPassenger();
    }
  }

  private mapCenterLon(): number {
    if (this.hasFocus) {
      return this.focusLon;
    }
    // Prefer passenger when driver is absurdly far (emulator GPS outside city).
    if (this.hasDriver && this.hasPassenger) {
      const far: boolean =
        Math.abs(this.driverLat - this.passengerLat) > 2 ||
        Math.abs(this.driverLon - this.passengerLon) > 2;
      if (far) {
        return this.passengerLon;
      }
      return (this.driverLon + this.passengerLon) / 2;
    }
    if (this.hasPassenger) {
      return this.passengerLon;
    }
    if (this.hasDriver) {
      return this.driverLon;
    }
    return 108.94;
  }

  private mapCenterLat(): number {
    if (this.hasFocus) {
      return this.focusLat;
    }
    if (this.hasDriver && this.hasPassenger) {
      const far: boolean =
        Math.abs(this.driverLat - this.passengerLat) > 2 ||
        Math.abs(this.driverLon - this.passengerLon) > 2;
      if (far) {
        return this.passengerLat;
      }
      return (this.driverLat + this.passengerLat) / 2;
    }
    if (this.hasPassenger) {
      return this.passengerLat;
    }
    if (this.hasDriver) {
      return this.driverLat;
    }
    return 34.25;
  }

  private mapZoom(): number {
    if (this.hasFocus) {
      return 15;
    }
    return 13;
  }


  private async useCurrentLocation(target: string): Promise<boolean> {
    if (this.locating) return false;
    this.locating = true;
    const revision: number = this.selectionRevision;
    this.locationError = '';
    try {
      const point: GeoPoint = await LocationService.readOnce(this.hostContext());
      if (this.disposed || (target !== 'missing' && revision !== this.selectionRevision)) return false;
      // A manually chosen endpoint must survive a slower location request.
      if (target === 'missing') {
        TripDraftStore.fillMissingFromCurrentLocation(point.lon, point.lat);
        this.hydrateDraft();
      }
      if (target === 'driver') {
        this.driverLon = point.lon; this.driverLat = point.lat;
        this.driverName = '当前位置'; this.hasDriver = true;
      }
      if (target === 'passenger') {
        this.passengerLon = point.lon; this.passengerLat = point.lat;
        this.passengerName = '当前位置'; this.hasPassenger = true;
      }
      this.focusLon = point.lon; this.focusLat = point.lat; this.hasFocus = true;
      this.mapToken++;
      this.persistDraft();
      this.searchOpen = false;
      return true;
    } catch (_) {
      if (!this.disposed) {
        this.locationError = '未能获取当前位置，请允许定位后重试，或搜索地点、在地图选点。';
        promptAction.showToast({ message: this.locationError });
      }
      return false;
    } finally { this.locating = false; }
  }

  private chooseSearchHit(hit: PoiHit): void {
    this.pendingLon = hit.lon; this.pendingLat = hit.lat; this.pendingName = hit.name;
    this.searchOpen = false;
    this.locationError = '';
    if (this.searchDriver) this.assignAsDriver();
    else this.assignAsPassenger();
  }

  private async openPlan(): Promise<void> {
    if (this.openingPlan || this.locating) return;
    if (this.settings.mapWebKey.trim().length === 0) {
      this.locationError = '请先在设置中配置高德 Web 服务 Key';
      promptAction.showToast({ message: this.locationError });
      return;
    }
    this.openingPlan = true;
    try {
      if ((!this.hasDriver || !this.hasPassenger) && !await this.useCurrentLocation('missing')) return;
      if (this.disposed) return;
      this.persistDraft();
      // Transit routing needs the passenger's actual city, including when GPS supplied it.
      if (this.settings.mapWebKey.trim().length > 0) {
        try {
          const city: string = await new AmapWebMapProvider(this.settings.mapWebKey).lookupCity(
            new GeoPoint(this.passengerLon, this.passengerLat));
          if (city.length > 0) TripDraftStore.setCity(city);
        } catch (_) { /* Existing city remains available during a geocoder outage. */ }
      }
      if (!this.disposed) await router.pushUrl({ url: 'pages/PlanPage' });
    } catch (_) {
      promptAction.showToast({ message: '暂时无法打开规划，请重试' });
    } finally { this.openingPlan = false; }
  }

  @Builder
  locationRow(isDriver: boolean) {
    Row({ space: 12 }) {
      Circle().width(10).height(10).fill(isDriver ? AppTheme.accent : AppTheme.success)
      Text(isDriver ? '司机' : '乘客').fontSize(13).fontColor(AppTheme.inkSoft).width(34)
      Text(isDriver
        ? (this.hasDriver ? this.displayPlace(this.driverName) : '当前位置 · 点此更改')
        : (this.hasPassenger ? this.displayPlace(this.passengerName) : '当前位置 · 点此更改')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      Text('›').fontSize(20).fontColor(AppTheme.inkSoft)
    }.width('100%').height(38).id(isDriver ? 'driver-location' : 'passenger-location').accessibilityText(isDriver ? '搜索司机出发地' : '搜索乘客位置')
      .onClick(() => { this.searchDriver = isDriver; this.searchOpen = true; })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 0 })
    PageTransitionExit({ duration: 0 })
  }

  build() {
    Stack() {
      StageBackground()
      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('会合').fontSize(30).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
            Text('少一点等待，多一点相聚').fontSize(13).fontColor(AppTheme.inkSoft)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('会合助手').fontSize(12).fontColor(AppTheme.accent)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(AppTheme.accentSoft).borderRadius(16)
        }.width('100%').padding({ left: 22, right: 22, top: AppLayout.headerTop(), bottom: 16 })

        InteractiveMapView({
          mapWebKey: this.mapKeyForView(), pickRole: 'passenger',
          driverLon: this.driverLon, driverLat: this.driverLat, hasDriver: this.hasDriver,
          passengerLon: this.passengerLon, passengerLat: this.passengerLat, hasPassenger: this.hasPassenger,
          centerLon: this.mapCenterLon(), centerLat: this.mapCenterLat(), zoom: this.mapZoom(),
          title: '轻点地图选点，或点下方位置搜索', reloadToken: this.mapToken,
          showTraffic: true, allowRoleSwitch: false,
          onPick: (ev: MapPickEvent) => { this.onMapPick(ev); },
          onChoose: (ev: MapChooseEvent) => { this.onMapChoose(ev); }
        }).width('100%').layoutWeight(1)

        Column({ space: 8 }) {
          Row() {
            Text('在哪里会合？').fontSize(21).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
            Blank()
            Text('未设置的位置使用当前位置').fontSize(11).fontColor(AppTheme.inkSoft)
          }.width('100%')
          Column() {
            this.locationRow(true)
            Divider().color(AppTheme.line).margin({ left: 22 })
            this.locationRow(false)
          }.width('100%').padding({ left: 14, right: 14, top: 4, bottom: 4 })
            .backgroundColor(AppTheme.fieldBg).borderRadius(18)
          if (this.locationError.length > 0) {
            Text(this.locationError).fontSize(12).fontColor(AppTheme.danger).width('100%')
          }
          Button(this.openingPlan ? '正在准备路线…' : '规划会合路线', { type: ButtonType.Capsule })
            .width('100%').height(48).fontSize(16).fontWeight(FontWeight.Medium)
            .backgroundColor(AppTheme.accent).fontColor(Color.White)
            .enabled(!this.openingPlan && !this.locating)
            .onClick(() => { this.openPlan(); })
        }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 14 })
          .backgroundColor(AppTheme.bg1)
        BottomNavigation({ active: 'map' })
      }.width('100%').height('100%')

      if (this.searchOpen) {
        LocationSearchSheet({
          isDriver: this.searchDriver, mapKey: this.settings.mapWebKey,
          nearLon: this.mapCenterLon(), nearLat: this.mapCenterLat(), locating: this.locating,
          onChoose: (hit: PoiHit) => { this.chooseSearchHit(hit); },
          onCurrent: () => { this.useCurrentLocation(this.searchDriver ? 'driver' : 'passenger'); },
          onClose: () => { this.searchOpen = false; }
        })
      }
      if (this.assignOpen) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column().width('100%').height('100%').backgroundColor('#44000000')
            .onClick(() => { this.closeAssign(); })
          Column({ space: 14 }) {
            Text('选择地点用途').fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
            Text(this.pendingName).fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
              .width('100%').maxLines(2)
            Button('设为司机出发地').width('100%').height(48).fontColor(Color.White)
              .backgroundColor(AppTheme.accent).onClick(() => { this.assignAsDriver(); })
            Button('设为乘客位置').width('100%').height(48).fontColor(AppTheme.accent)
              .backgroundColor(AppTheme.accentSoft).onClick(() => { this.assignAsPassenger(); })
            Button('取消').width('100%').height(40).fontColor(AppTheme.inkSoft)
              .backgroundColor(Color.Transparent).onClick(() => { this.closeAssign(); })
          }.width('100%').padding({ left: 24, right: 24, top: 26, bottom: 34 })
            .backgroundColor(AppTheme.bg1).borderRadius({ topLeft: 28, topRight: 28 })
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor(AppTheme.bg0)
  }
}
