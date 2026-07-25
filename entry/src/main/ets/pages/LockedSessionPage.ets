/**
 * Locked trip session screen — confirmed plan snapshot.
 * Share + open maps; explicit re-plan only (does not mutate locked session).
 * Map: InteractiveMapView (same stack as Plan/Chat results) with deferred first paint.
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AppSettings } from '../common/AppSettings';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
import { StageBackground } from '../common/GlassChrome';
import {
  dataSourceLabelZh,
  GeoPoint,
  NamedPoint,
  TripSession
} from '../domain/Models';
import {
  LockedPlanSnapshot,
  resolveLockedPlan
} from '../services/session/SessionLogic';
import { ShareService } from '../services/session/ShareService';
import { TripSessionStore } from '../services/session/TripSessionStore';
import { MapLinkService } from '../services/map/MapLinkService';
import { InteractiveMapView } from '../services/map/InteractiveMapView';
import { SettingsStore } from '../services/settings/SettingsStore';

@Entry
@Component
struct LockedSessionPage {
  @State settings: AppSettings = new AppSettings();
  @State hasSession: boolean = false;
  @State sessionId: string = '';
  @State lockedAt: string = '';
  @State dataSourceBadge: string = '';
  @State modeLabel: string = '';
  @State meetingName: string = '';
  @State meetingAddress: string = '';
  @State meetingLon: number = 0;
  @State meetingLat: number = 0;
  @State driverEtaText: string = '';
  @State passengerEtaText: string = '';
  @State completionText: string = '';
  @State rationale: string = '';
  @State planId: string = '';
  @State sharePreview: string = '';
  @State statusLine: string = '';
  @State driverLine: GeoPoint[] = [];
  @State passengerLine: GeoPoint[] = [];
  @State meeting: NamedPoint = new NamedPoint();
  /** Origin pins from locked recommendation (GCJ-02). */
  @State driverLon: number = 108.89;
  @State driverLat: number = 34.23;
  @State passengerLon: number = 108.95;
  @State passengerLat: number = 34.26;
  @State mapToken: number = 0;
  @State mapReady: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  private hostContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private async bootstrap(): Promise<void> {
    try {
      this.settings = await SettingsStore.load(this.hostContext());
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settings = new AppSettings();
    }
    const locked: TripSession | null = TripSessionStore.getLocked();
    if (locked === null) {
      this.hasSession = false;
      this.statusLine = '没有已锁定的会合方案，请先在规划页确认。';
      return;
    }
    this.applyLocked(locked);
    // Defer Web map mount so first layout has non-zero size (same as Plan/Chat).
    this.mapReady = false;
    setTimeout(() => {
      this.bootstrapMap();
    }, 80);
  }

  private bootstrapMap(): void {
    this.mapReady = true;
    this.mapToken = this.mapToken + 1;
    setTimeout(() => {
      this.mapToken = this.mapToken + 1;
    }, 120);
  }

  private copyLine(src: GeoPoint[]): GeoPoint[] {
    const out: GeoPoint[] = [];
    for (let i = 0; i < src.length; i++) {
      out.push(new GeoPoint(src[i].lon, src[i].lat));
    }
    return out;
  }

  /** Prefer POI/address; never show bare coords as the primary line. */
  private placeLabel(name: string, address: string): string {
    const n: string = name.trim();
    const a: string = address.trim();
    if (n.length > 0 && n.indexOf('会合点') !== 0) {
      // strip trailing " · lat,lon" if present
      const parts: string[] = n.split('·');
      if (parts.length >= 2) {
        const tail: string = parts[parts.length - 1].trim();
        if (tail.indexOf(',') >= 0) {
          const c0: string = tail.length > 0 ? tail.charAt(0) : '';
          if (c0 >= '0' && c0 <= '9') {
            let head: string = parts[0].trim();
            for (let i = 1; i < parts.length - 1; i++) {
              head = `${head} · ${parts[i].trim()}`;
            }
            if (head.length > 0) {
              return head;
            }
          }
        }
      }
      if (!(n.indexOf(',') > 0 && n.charAt(0) >= '0' && n.charAt(0) <= '9')) {
        return n;
      }
    }
    if (a.length > 0 && !(a.indexOf(',') > 0 && a.charAt(0) >= '0' && a.charAt(0) <= '9')) {
      return a;
    }
    return n.length > 0 ? n : '会合点附近';
  }

  private applyLocked(session: TripSession): void {
    this.hasSession = true;
    this.sessionId = session.id;
    this.lockedAt = session.lockedAt.length > 0 ? session.lockedAt : '已锁定';
    const snap: LockedPlanSnapshot = resolveLockedPlan(session);
    this.planId = snap.planId;
    this.modeLabel = snap.modeLabel;
    this.dataSourceBadge = dataSourceLabelZh(snap.dataSource);

    const rec = session.recommendationSet;
    this.driverLon = rec.driverStart.lon !== 0 ? rec.driverStart.lon : 108.89;
    this.driverLat = rec.driverStart.lat !== 0 ? rec.driverStart.lat : 34.23;
    this.passengerLon = rec.passengerStart.lon !== 0 ? rec.passengerStart.lon : 108.95;
    this.passengerLat = rec.passengerStart.lat !== 0 ? rec.passengerStart.lat : 34.26;

    this.meetingName = this.placeLabel(snap.meetingPoint.name, snap.meetingPoint.address);
    this.meetingAddress =
      snap.meetingPoint.address.length > 0 &&
      snap.meetingPoint.address !== this.meetingName
        ? snap.meetingPoint.address
        : '';
    this.meetingLon = snap.meetingPoint.lon;
    this.meetingLat = snap.meetingPoint.lat;
    this.meeting = new NamedPoint(
      snap.meetingPoint.lon,
      snap.meetingPoint.lat,
      this.meetingName,
      this.meetingAddress
    );
    this.driverEtaText = `司机约 ${snap.driverEtaMin.toFixed(0)} 分钟`;
    if (snap.kind === 'stayPut') {
      this.passengerEtaText = '乘客原地等待';
    } else {
      this.passengerEtaText = `乘客约 ${snap.passengerEtaMin.toFixed(0)} 分钟（${snap.modeLabel}）`;
    }
    this.completionText = `会合完成约 ${snap.completionMin.toFixed(0)} 分钟`;
    this.rationale = snap.rationale;
    this.driverLine = this.copyLine(snap.driverRoutePolyline);
    this.passengerLine = this.copyLine(snap.passengerPathPolyline);
    this.sharePreview = ShareService.buildShareTextFromSession(session);
    this.statusLine = `已锁定 · ${this.dataSourceBadge} · 不会自动改点`;
  }

  private mapCenterLon(): number {
    if (this.meetingLon !== 0) {
      return this.meetingLon;
    }
    return (this.driverLon + this.passengerLon) / 2;
  }

  private mapCenterLat(): number {
    if (this.meetingLat !== 0) {
      return this.meetingLat;
    }
    return (this.driverLat + this.passengerLat) / 2;
  }

  private async onShare(): Promise<void> {
    const locked: TripSession | null = TripSessionStore.getLocked();
    if (locked === null) {
      promptAction.showToast({ message: '无锁定方案', duration: 1600 });
      return;
    }
    try {
      await ShareService.shareLockedSession(locked);
    } catch (e) {
      const _ignored: Object = e as Object;
      promptAction.showToast({ message: '复制失败', duration: 1600 });
    }
  }

  private async onOpenMaps(): Promise<void> {
    if (!this.hasSession) {
      return;
    }
    await MapLinkService.openMeeting(
      this.hostContext(),
      this.meetingLon,
      this.meetingLat,
      this.meetingName,
      this.settings.mapApp
    );
  }

  private onReplan(): void {
    TripSessionStore.replan();
    promptAction.showToast({ message: '已关闭锁定会话，可重新规划', duration: 1600 });
    router.replaceUrl({ url: 'pages/PlanPage' }).catch(() => {
      router.back();
    });
  }

  private goBack(): void {
    router.back();
  }

  build() {
    Stack() {
      StageBackground()

      Column() {
        // header
        Row() {
          Button({ type: ButtonType.Normal }) {
            Text('‹')
              .fontSize(24)
              .fontColor(AppTheme.ink)
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.goBack();
          })

          Text('已锁定方案')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button('设置', { type: ButtonType.Capsule })
            .height(34)
            .fontSize(13)
            .backgroundColor(AppTheme.glassBg)
            .fontColor(AppTheme.ink)
            .border({ width: 1, color: AppTheme.glassBorder })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
                promptAction.showToast({ message: '无法打开设置', duration: 1600 });
              });
            })
        }
        .width('100%')
        .padding({
          left: 12,
          right: 16,
          top: AppLayout.headerTop(),
          bottom: 8
        })

        Text(this.statusLine)
          .fontSize(12)
          .fontColor(AppTheme.inkMuted)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 6 })

        if (!this.hasSession) {
          Column({ space: 14 }) {
            Text('暂无锁定方案')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
              .width('100%')
              .textAlign(TextAlign.Center)
            Text(this.statusLine)
              .fontSize(14)
              .fontColor(AppTheme.inkMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
            Button('去普通规划', { type: ButtonType.Capsule })
              .width('100%')
              .height(46)
              .backgroundColor(AppTheme.accent)
              .fontColor(Color.White)
              .onClick(() => {
                router.replaceUrl({ url: 'pages/PlanPage' }).catch(() => {
                  router.back();
                });
              })
            Button('去智能助手', { type: ButtonType.Capsule })
              .width('100%')
              .height(42)
              .backgroundColor(AppTheme.glassBg)
              .fontColor(AppTheme.ink)
              .border({ width: 1, color: AppTheme.glassBorder })
              .onClick(() => {
                router.replaceUrl({ url: 'pages/ChatPage' }).catch(() => {
                  router.back();
                });
              })
          }
          .width('100%')
          .padding(24)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              // Interactive map (locked snapshot routes)
              Stack() {
                if (this.mapReady) {
                  InteractiveMapView({
                    mapWebKey: this.settings.demoFixtures ? '' : this.settings.mapWebKey,
                    pickRole: 'none',
                    driverLon: this.driverLon,
                    driverLat: this.driverLat,
                    hasDriver: true,
                    passengerLon: this.passengerLon,
                    passengerLat: this.passengerLat,
                    hasPassenger: true,
                    centerLon: this.mapCenterLon(),
                    centerLat: this.mapCenterLat(),
                    zoom: 13,
                    title: `已锁定 · ${this.dataSourceBadge}`,
                    driverLine: this.driverLine,
                    passengerLine: this.passengerLine,
                    showTraffic: !this.settings.demoFixtures &&
                      this.settings.mapWebKey.trim().length > 0,
                    allowRoleSwitch: false,
                    showChrome: false,
                    reloadToken: this.mapToken
                  })
                    .width('100%')
                    .height(240)
                    .key(`locked-map-${this.mapToken}-${this.sessionId}`)
                } else {
                  Column() {
                    Text('地图加载中…')
                      .fontSize(13)
                      .fontColor(AppTheme.inkMuted)
                  }
                  .width('100%')
                  .height(240)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(AppTheme.mapPanel)
                }

                Text(this.modeLabel)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(AppTheme.accent)
                  .borderRadius(999)
                  .position({ x: 10, y: 10 })
              }
              .width('100%')
              .height(240)
              .clip(true)
              .borderRadius(16)
              .border({ width: 1, color: AppTheme.glassBorder })

              Column({ space: 8 }) {
                Text('会合地点')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.link)
                  .width('100%')
                Text(this.meetingName)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.ink)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.meetingAddress.length > 0) {
                  Text(this.meetingAddress)
                    .fontSize(12)
                    .fontColor(AppTheme.inkMuted)
                    .width('100%')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .padding(16)
              .borderRadius(16)
              .backgroundColor(AppTheme.glassBgStrong)
              .border({ width: 1, color: AppTheme.glassBorder })
              .backdropBlur(AppTheme.blurSoft)

              Column({ space: 6 }) {
                Text(this.modeLabel)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .width('100%')
                Text(this.driverEtaText)
                  .fontSize(14)
                  .fontColor('#EAF2FF')
                  .width('100%')
                Text(this.passengerEtaText)
                  .fontSize(14)
                  .fontColor('#EAF2FF')
                  .width('100%')
                Text(this.completionText)
                  .fontSize(13)
                  .fontColor('#D6E8FF')
                  .width('100%')
                if (this.rationale.length > 0) {
                  Text(this.rationale)
                    .fontSize(12)
                    .fontColor('#D6E8FF')
                    .width('100%')
                    .margin({ top: 4 })
                }
              }
              .width('100%')
              .padding(16)
              .borderRadius(16)
              .backgroundColor(AppTheme.accent)
              .border({ width: 1, color: AppTheme.glassBorder })

              Column({ space: 6 }) {
                Text('分享预览')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.link)
                  .width('100%')
                Text(this.sharePreview)
                  .fontSize(12)
                  .fontColor(AppTheme.inkMuted)
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(AppTheme.glassBg)
              .border({ width: 1, color: AppTheme.glassBorder })

              Button('复制分享', { type: ButtonType.Capsule })
                .width('100%')
                .height(48)
                .backgroundColor('#BF5AF2')
                .fontColor(Color.White)
                .onClick(() => {
                  this.onShare();
                })

              Button('在地图中打开', { type: ButtonType.Capsule })
                .width('100%')
                .height(46)
                .backgroundColor(AppTheme.accent)
                .fontColor(Color.White)
                .onClick(() => {
                  this.onOpenMaps();
                })

              Button('重新规划', { type: ButtonType.Capsule })
                .width('100%')
                .height(44)
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(AppTheme.ink)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.onReplan();
                })

              Text(`会话 ${this.sessionId} · ${this.lockedAt}`)
                .fontSize(11)
                .fontColor(AppTheme.inkSoft)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 12 })
            }
            .width('100%')
            .padding({ left: 14, right: 14, bottom: 28, top: 4 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
