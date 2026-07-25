import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
import { StageBackground } from '../common/GlassChrome';
import { AppSettings } from '../common/AppSettings';
import { SettingsStore } from '../services/settings/SettingsStore';
import { InteractiveMapView, MapPickEvent, MapChooseEvent } from '../services/map/InteractiveMapView';
import { PlanningService } from '../services/map/MapProvider';
import { GeoPoint } from '../domain/Models';
import { TripDraftStore } from '../services/session/TripDraftStore';

/**
 * Home: interactive map stage (AMap JS Web when key present) + fixed-height
 * scrollable bottom sheet. Role mode lives as header UR chip — not map-center.
 */
@Entry
@Component
struct Index {
  @State settings: AppSettings = new AppSettings();
  @State settingsSummary: string = '设置加载中…';
  /**
   * Planning role (single device). Not dual-phone sync.
   * 'driver' | 'passenger'
   */
  @State roleMode: string = 'driver';
  /** Expanded mode picker (collapsed chip → menu). */
  @State modeMenuOpen: boolean = false;
  /** Bottom sheet height vp — fixed so map stage keeps visible space. */
  private readonly sheetHeightVp: number = 320;

  // Map draft (GCJ-02). Defaults = 西安 demo corridor.
  @State driverLon: number = 108.8905;
  @State driverLat: number = 34.2324;
  @State hasDriver: boolean = true;
  @State passengerLon: number = 108.9465;
  @State passengerLat: number = 34.2610;
  @State hasPassenger: boolean = true;
  @State passengerName: string = '乘客（钟楼附近）';
  @State driverName: string = '司机起点（高新）';
  @State mapToken: number = 0;
  @State pickHint: string = '搜索或点选地点后，选择用途';
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
    this.refreshSettings();
    this.hydrateDraft();
  }

  onPageShow(): void {
    this.refreshSettings();
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
    // Demo fixtures force schematic HTML path (no live tiles) for stage stability.
    if (this.settings.demoFixtures) {
      return '';
    }
    return this.settings.mapWebKey;
  }

  private pickRoleForMap(): string {
    // Search-first: map does not pre-bind role; host assigns after choose.
    return 'passenger';
  }

  private async refreshSettings(): Promise<void> {
    try {
      this.settings = await SettingsStore.load(this.hostContext());
      const llm: string = this.settings.llmConfigured()
        ? `LLM ${this.settings.modeLabel()} · ${this.settings.llmModel}`
        : `LLM ${this.settings.modeLabel()} · 引擎估算可用`;
      let map: string = '示意地图';
      if (this.settings.demoFixtures) {
        map = '演示 Fixture · 示意地图';
      } else if (this.settings.mapWebKey.trim().length > 0) {
        map = 'AMap 底图+路况+路线';
      }
      this.settingsSummary = `${llm} · ${map}`;
      this.mapToken = this.mapToken + 1;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settingsSummary = '设置读取失败 — 默认离线模式';
    }
  }

  private onMapChoose(ev: MapChooseEvent): void {
    this.pendingLon = ev.lon;
    this.pendingLat = ev.lat;
    this.pendingName = ev.name.length > 0 ? ev.name : '地图选点';
    this.assignOpen = true;
    this.pickHint = `已选：${this.pendingName}`;
  }

  private closeAssign(): void {
    this.assignOpen = false;
  }

  /** UI label: never show bare lat/lon. */
  private displayPlace(name: string): string {
    const n: string = name.trim();
    if (n.length === 0 || n === '地图选点' || n === '当前位置') {
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
    if (n.length === 0 || n === '地图选点' || n === '当前位置' || n === '附近地点') {
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
      const provider = PlanningService.createProvider(this.settings.mapWebKey, this.settings.demoFixtures);
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
    this.passengerLon = this.pendingLon;
    this.passengerLat = this.pendingLat;
    this.hasPassenger = true;
    this.passengerName = this.pendingName;
    this.focusLon = this.pendingLon;
    this.focusLat = this.pendingLat;
    this.hasFocus = true;
    this.assignOpen = false;
    this.mapToken = this.mapToken + 1;
    this.pickHint = `乘客位置：${this.displayPlace(this.passengerName)}`;
    promptAction.showToast({ message: '已设为乘客位置', duration: 1400 });
    this.finalizePassengerLabel();
  }

  private assignAsDriver(): void {
    this.driverLon = this.pendingLon;
    this.driverLat = this.pendingLat;
    this.hasDriver = true;
    this.driverName = this.pendingName;
    this.focusLon = this.pendingLon;
    this.focusLat = this.pendingLat;
    this.hasFocus = true;
    this.assignOpen = false;
    this.mapToken = this.mapToken + 1;
    this.pickHint = `司机起点：${this.displayPlace(this.driverName)}`;
    promptAction.showToast({ message: '已设为司机起点', duration: 1400 });
    this.finalizeDriverLabel();
  }

  private async finalizePassengerLabel(): Promise<void> {
    const label: string = await this.resolvePlaceName(
      this.passengerLon,
      this.passengerLat,
      this.passengerName
    );
    this.passengerName = label;
    this.persistDraft();
    this.pickHint = `乘客位置：${this.displayPlace(label)}`;
    this.mapToken = this.mapToken + 1;
  }

  private async finalizeDriverLabel(): Promise<void> {
    const label: string = await this.resolvePlaceName(
      this.driverLon,
      this.driverLat,
      this.driverName
    );
    this.driverName = label;
    this.persistDraft();
    this.pickHint = `司机起点：${this.displayPlace(label)}`;
    this.mapToken = this.mapToken + 1;
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

  private openSettings(): void {
    this.modeMenuOpen = false;
    router.pushUrl({ url: 'pages/SettingsPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开设置页';
    });
  }

  private openPlan(): void {
    this.modeMenuOpen = false;
    this.persistDraft();
    router.pushUrl({ url: 'pages/PlanPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开规划页';
    });
  }

  private openChat(): void {
    this.modeMenuOpen = false;
    this.persistDraft();
    router.pushUrl({ url: 'pages/ChatPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开助手页';
    });
  }

  private openLocked(): void {
    this.modeMenuOpen = false;
    router.pushUrl({ url: 'pages/LockedSessionPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开锁定方案页';
    });
  }

  private modeChipLabel(): string {
    return this.roleMode === 'passenger' ? '乘客模式' : '司机模式';
  }

  private toggleModeMenu(): void {
    this.modeMenuOpen = !this.modeMenuOpen;
  }

  private selectRoleMode(mode: string): void {
    if (mode === 'driver' || mode === 'passenger') {
      this.roleMode = mode;
    }
    this.modeMenuOpen = false;
    this.mapToken = this.mapToken + 1;
  }

  build() {
    Stack() {
      // Full-bleed stage (draws under status / nav bars)
      StageBackground()
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Column() {
        // —— Top chrome: title | mode chip (UR) | settings ——
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('会合助手')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
            Text('MeetAgent · liquid glass')
              .fontSize(11)
              .fontColor(AppTheme.inkSoft)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // Collapsed mode pill — upper right, not on map
          Button(this.modeChipLabel(), { type: ButtonType.Capsule })
            .height(34)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#5AC8C8')
            .border({ width: 1, color: '#66FFFFFF' })
            .shadow({
              radius: 12,
              color: '#4000A8A8',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              this.toggleModeMenu();
            })

          Button('设置', { type: ButtonType.Capsule })
            .height(34)
            .fontSize(13)
            .backgroundColor(AppTheme.glassBgLight)
            .fontColor(AppTheme.ink)
            .border({ width: 1, color: AppTheme.glassBorder })
            .backdropBlur(AppTheme.blurSoft)
            .onClick(() => {
              this.openSettings();
            })
        }
        .width('100%')
        .padding({ left: 18, right: 16, top: 8, bottom: 6 })
        // Keep title below status bar while stage fills behind it
        .margin({ top: AppLayout.statusBarInsetVp })

        // —— Map stage (interactive AMap / schematic) ——
        Column({ space: 6 }) {
          Column({ space: 2 }) {
            Text(
              this.mapKeyForView().length > 0 ? '实时地图' : '示意地图'
            )
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
              .width('100%')
              .textAlign(TextAlign.Start)
            Text(this.pickHint)
              .fontSize(11)
              .fontColor(AppTheme.inkMuted)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 18, right: 18 })

          Stack() {
            // key-like remount: when mapToken changes, rebuild Web with new pins
            InteractiveMapView({
              mapWebKey: this.mapKeyForView(),
              pickRole: this.pickRoleForMap(),
              driverLon: this.driverLon,
              driverLat: this.driverLat,
              hasDriver: this.hasDriver,
              passengerLon: this.passengerLon,
              passengerLat: this.passengerLat,
              hasPassenger: this.hasPassenger,
              centerLon: this.mapCenterLon(),
              centerLat: this.mapCenterLat(),
              zoom: this.mapZoom(),
              title: `搜索地点后选择用途 · 路况 · t${this.mapToken}`,
              reloadToken: this.mapToken,
              showTraffic: true,
              allowRoleSwitch: false,
              onPick: (ev: MapPickEvent) => {
                this.onMapPick(ev);
              },
              onChoose: (ev: MapChooseEvent) => {
                this.onMapChoose(ev);
              }
            })
              .key(`map-${this.mapToken}`)
          }
          .width('100%')
          .layoutWeight(1)
          .constraintSize({ minHeight: 160 })
          .margin({ left: 18, right: 18, bottom: 6 })
          .clip(true)
          .borderRadius(16)
          .border({ width: 1, color: AppTheme.glassBorder })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // —— Fixed-height scrollable bottom sheet ——
        Column() {
          Row() {
            Column()
              .width(40)
              .height(4)
              .borderRadius(2)
              .backgroundColor(AppTheme.glassBorder)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 4 })

          Scroll() {
            Column({ space: 12 }) {
              Text('接驾会合规划')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
                .width('100%')
              Text('在地图搜索或点选地点，再选择设为乘客或司机。')
                .fontSize(12)
                .fontColor(AppTheme.inkMuted)
                .width('100%')

              Column({ space: 6 }) {
                Text('乘客位置')
                  .fontSize(12)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')
                Text(
                  this.hasPassenger
                    ? this.displayPlace(this.passengerName)
                    : '尚未选择 — 地图搜索/点选后指定'
                )
                  .fontSize(13)
                  .fontColor(this.hasPassenger ? AppTheme.ink : AppTheme.inkFaint)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .padding(12)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .border({ width: 1, color: AppTheme.lineStrong })
              }
              .width('100%')

              Column({ space: 6 }) {
                Text('司机出发地')
                  .fontSize(12)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')
                Text(
                  this.hasDriver
                    ? this.displayPlace(this.driverName)
                    : '尚未选择 — 地图搜索/点选后指定'
                )
                  .fontSize(13)
                  .fontColor(this.hasDriver ? AppTheme.ink : AppTheme.inkFaint)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .padding(12)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .border({ width: 1, color: AppTheme.lineStrong })
              }
              .width('100%')

              Text(this.settingsSummary)
                .fontSize(11)
                .fontColor(AppTheme.inkSoft)
                .width('100%')

              Button('智能助手规划', { type: ButtonType.Capsule })
                .width('100%')
                .height(50)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(AppTheme.accent)
                .fontColor(Color.White)
                .border({ width: 1, color: '#59FFFFFF' })
                .shadow({
                  radius: 22,
                  color: '#590A84FF',
                  offsetX: 0,
                  offsetY: 10
                })
                .onClick(() => {
                  this.openChat();
                })

              Button('普通规划', { type: ButtonType.Capsule })
                .width('100%')
                .height(44)
                .fontSize(14)
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(AppTheme.ink)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.openPlan();
                })

              Button('已锁定方案', { type: ButtonType.Capsule })
                .width('100%')
                .height(42)
                .fontSize(14)
                .backgroundColor(AppTheme.glassBg)
                .fontColor(AppTheme.inkMuted)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.openLocked();
                })

              Text('选点后进入规划 · 演示 Fixture 开启时强制估算 · Key 仅存本机')
                .fontSize(11)
                .fontColor(AppTheme.inkSoft)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 8 })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 6, bottom: 20 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.Top)
        }
        .width('100%')
        .height(this.sheetHeightVp)
        .borderRadius({ topLeft: AppTheme.radiusLg, topRight: AppTheme.radiusLg })
        .backgroundColor(AppTheme.glassBg)
        .backdropBlur(AppTheme.blurStrong)
        .border({ width: { top: 1 }, color: AppTheme.glassBorder })
        .shadow({
          radius: 36,
          color: '#80000000',
          offsetX: 0,
          offsetY: -8
        })
        .clip(true)
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // —— Mode selection overlay ——
      if (this.modeMenuOpen) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .onClick(() => {
              this.modeMenuOpen = false;
            })

          Column({ space: 10 }) {
            Text('选择模式')
              .fontSize(13)
              .fontColor(AppTheme.inkSoft)
              .width('100%')

            Row() {
              Text('我是司机')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .layoutWeight(1)
              if (this.roleMode === 'driver') {
                Text('✓')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 14 })
            .borderRadius(14)
            .backgroundColor(this.roleMode === 'driver' ? '#3A4A5C' : '#2A3544')
            .border({
              width: 1,
              color: this.roleMode === 'driver' ? AppTheme.lineFocus : AppTheme.line
            })
            .onClick(() => {
              this.selectRoleMode('driver');
            })

            Row() {
              Text('我是乘客')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .layoutWeight(1)
              if (this.roleMode === 'passenger') {
                Text('✓')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 14 })
            .borderRadius(14)
            .backgroundColor(this.roleMode === 'passenger' ? '#3A4A5C' : '#2A3544')
            .border({
              width: 1,
              color: this.roleMode === 'passenger' ? AppTheme.lineFocus : AppTheme.line
            })
            .onClick(() => {
              this.selectRoleMode('passenger');
            })

            Text('单机规划视角 · 非双机同步')
              .fontSize(10)
              .fontColor(AppTheme.inkSoft)
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          .width(260)
          .padding(16)
          .margin({ top: AppLayout.headerTop() + 48, right: 16 })
          .borderRadius(18)
          .backgroundColor('#E0182430')
          .backdropBlur(AppTheme.blurPanel)
          .border({ width: 1, color: AppTheme.glassBorder })
          .shadow({
            radius: 28,
            color: '#80000000',
            offsetX: 0,
            offsetY: 12
          })
        }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }

      // —— Assign place after search / map tap ——
      if (this.assignOpen) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#99000000')
            .onClick(() => {
              this.closeAssign();
            })

          Column({ space: 12 }) {
            Text(this.roleMode === 'driver' ? '从其他位置出发？' : '确认地点用途')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
            Text(this.pendingName)
              .fontSize(14)
              .fontColor('#D9FFFFFF')
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.pendingLat.toFixed(5)}, ${this.pendingLon.toFixed(5)}`)
              .fontSize(12)
              .fontColor(AppTheme.inkSoft)
              .width('100%')

            if (this.roleMode === 'driver') {
              Button('我的乘客在这里', { type: ButtonType.Capsule })
                .width('100%')
                .height(48)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#34C759')
                .fontColor(Color.White)
                .onClick(() => {
                  this.assignAsPassenger();
                })
              Button('我从这里出发', { type: ButtonType.Capsule })
                .width('100%')
                .height(44)
                .fontSize(14)
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(Color.White)
                .border({ width: 1, color: '#66FFFFFF' })
                .onClick(() => {
                  this.assignAsDriver();
                })
            } else {
              Button('我在这里', { type: ButtonType.Capsule })
                .width('100%')
                .height(48)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#34C759')
                .fontColor(Color.White)
                .onClick(() => {
                  this.assignAsPassenger();
                })
              Button('我的司机会从这里出发', { type: ButtonType.Capsule })
                .width('100%')
                .height(44)
                .fontSize(14)
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(Color.White)
                .border({ width: 1, color: '#66FFFFFF' })
                .onClick(() => {
                  this.assignAsDriver();
                })
            }

            Button('取消', { type: ButtonType.Capsule })
              .width('100%')
              .height(40)
              .fontSize(13)
              .backgroundColor(Color.Transparent)
              .fontColor(AppTheme.inkMuted)
              .onClick(() => {
                this.closeAssign();
              })
          }
          .width('86%')
          .padding(18)
          .borderRadius(18)
          .backgroundColor('#E0182430')
          .backdropBlur(AppTheme.blurPanel)
          .border({ width: 1, color: AppTheme.glassBorder })
          .shadow({
            radius: 28,
            color: '#80000000',
            offsetX: 0,
            offsetY: 12
          })
        }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
