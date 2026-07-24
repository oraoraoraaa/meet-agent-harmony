/**
 * Locked trip session screen — confirmed plan snapshot.
 * Share + open maps; explicit re-plan only (does not mutate locked session).
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AppSettings } from '../common/AppSettings';
import { AppTheme } from '../common/AppTheme';
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
import { SettingsStore } from '../services/settings/SettingsStore';
import {
  CanvasPoint,
  computeBounds,
  PolylineBounds,
  projectPolyline
} from '../common/PolylineMath';

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
  @State mapW: number = 320;
  @State mapH: number = 160;

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
  }

  private applyLocked(session: TripSession): void {
    this.hasSession = true;
    this.sessionId = session.id;
    this.lockedAt = session.lockedAt.length > 0 ? session.lockedAt : '已锁定';
    const snap: LockedPlanSnapshot = resolveLockedPlan(session);
    this.planId = snap.planId;
    this.modeLabel = snap.modeLabel;
    this.dataSourceBadge = dataSourceLabelZh(snap.dataSource);
    this.meetingName = snap.meetingPoint.name.length > 0 ? snap.meetingPoint.name : '会合点';
    this.meetingAddress =
      snap.meetingPoint.address.length > 0
        ? snap.meetingPoint.address
        : `${snap.meetingPoint.lat.toFixed(5)}, ${snap.meetingPoint.lon.toFixed(5)}`;
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
    this.driverLine = snap.driverRoutePolyline;
    this.passengerLine = snap.passengerPathPolyline;
    this.sharePreview = ShareService.buildShareTextFromSession(session);
    this.statusLine = `已锁定 · ${this.dataSourceBadge} · 不会自动改点`;
  }

  private async onShare(): Promise<void> {
    const locked: TripSession | null = TripSessionStore.getLocked();
    if (locked === null) {
      promptAction.showToast({ message: '无锁定方案', duration: 1800 });
      return;
    }
    await ShareService.shareLockedSession(locked);
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
    promptAction.showToast({ message: '已关闭锁定方案，可重新规划', duration: 1800 });
    router.replaceUrl({ url: 'pages/PlanPage' }).catch(() => {
      router.back();
    });
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开设置', duration: 1800 });
    });
  }

  build() {
    Stack() {
      StageBackground()

      Column() {
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
            router.back();
          })

          Column({ space: 2 }) {
            Text('已锁定方案')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
            Text(this.statusLine)
              .fontSize(11)
              .fontColor(AppTheme.inkSoft)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.dataSourceBadge.length > 0 ? this.dataSourceBadge : '估算')
            .fontSize(11)
            .fontColor(AppTheme.ink)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(AppTheme.glassBgLight)
            .borderRadius(999)
            .border({ width: 1, color: AppTheme.glassBorder })
        }
        .width('100%')
        .padding({ left: 8, right: 12, top: 10, bottom: 6 })

        if (!this.hasSession) {
          Column({ space: 12 }) {
            Text(this.statusLine)
              .fontSize(14)
              .fontColor(AppTheme.inkMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
            Button('去表单规划', { type: ButtonType.Capsule })
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
              // schematic map
              Stack() {
                Column()
                  .width('100%')
                  .height(160)
                  .borderRadius(16)
                  .backgroundColor(AppTheme.mapPanel)
                LockedPolylinePreview({
                  driverLine: this.driverLine,
                  passengerLine: this.passengerLine,
                  meeting: this.meeting,
                  widthPx: this.mapW,
                  heightPx: this.mapH
                })
                  .width('100%')
                  .height(160)
                Text(this.modeLabel)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(AppTheme.accent)
                  .borderRadius(999)
                  .position({ x: 10, y: 10 })
                Text('示意路线 · 坐标已锁定')
                  .fontSize(10)
                  .fontColor(AppTheme.inkMuted)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor('#99000000')
                  .borderRadius(8)
                  .position({ x: 10, y: 130 })
              }
              .width('100%')
              .height(160)
              .clip(true)
              .borderRadius(16)
              .border({ width: 1, color: AppTheme.glassBorder })
              .onAreaChange((_oldValue: Area, area: Area) => {
                const w: number = Number(area.width);
                if (!isNaN(w) && w > 0) {
                  this.mapW = w;
                }
              })

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
                Text(this.meetingAddress)
                  .fontSize(12)
                  .fontColor(AppTheme.inkMuted)
                  .width('100%')
                Text(`${this.meetingLat.toFixed(5)}, ${this.meetingLon.toFixed(5)} · GCJ-02`)
                  .fontSize(11)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')
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
                Text(this.rationale)
                  .fontSize(12)
                  .fontColor('#D9FFFFFF')
                  .width('100%')
                  .margin({ top: 4 })
                Text(`方案 ID：${this.planId}`)
                  .fontSize(11)
                  .fontColor('#B3FFFFFF')
                  .width('100%')
                Text(`会话：${this.sessionId}`)
                  .fontSize(10)
                  .fontColor('#99FFFFFF')
                  .width('100%')
                Text(`锁定时间：${this.lockedAt}`)
                  .fontSize(10)
                  .fontColor('#99FFFFFF')
                  .width('100%')
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
                  .copyOption(CopyOptions.LocalDevice)
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(AppTheme.glassBg)
              .border({ width: 1, color: AppTheme.glassBorder })

              Row({ space: 10 }) {
                Button('复制分享', { type: ButtonType.Capsule })
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor('#BF5AF2')
                  .fontColor(Color.White)
                  .onClick(() => {
                    this.onShare();
                  })
                Button('在地图中打开', { type: ButtonType.Capsule })
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor(AppTheme.accent)
                  .fontColor(Color.White)
                  .onClick(() => {
                    this.onOpenMaps();
                  })
              }
              .width('100%')

              Button('重新规划（关闭锁定）', { type: ButtonType.Capsule })
                .width('100%')
                .height(44)
                .backgroundColor(AppTheme.card)
                .fontColor(AppTheme.inkMuted)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.onReplan();
                })

              Button('地图应用设置', { type: ButtonType.Capsule })
                .width('100%')
                .height(40)
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(AppTheme.ink)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.openSettings();
                })

              Text('v1：锁定后不会自动改会合点；仅手动「重新规划」开启新会话。')
                .fontSize(11)
                .fontColor(AppTheme.inkSoft)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 24 })
            }
            .width('100%')
            .padding({ left: 14, right: 14, bottom: 20, top: 4 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
  }
}

@Component
struct LockedPolylinePreview {
  @Prop driverLine: GeoPoint[] = [];
  @Prop passengerLine: GeoPoint[] = [];
  @Prop meeting: NamedPoint = new NamedPoint();
  @Prop widthPx: number = 320;
  @Prop heightPx: number = 160;

  private bounds(): PolylineBounds {
    const lines: GeoPoint[][] = [];
    if (this.driverLine.length > 0) {
      lines.push(this.driverLine);
    }
    if (this.passengerLine.length > 0) {
      lines.push(this.passengerLine);
    }
    if (this.meeting.lon !== 0 || this.meeting.lat !== 0) {
      const meetLine: GeoPoint[] = [];
      meetLine.push(new GeoPoint(this.meeting.lon, this.meeting.lat));
      lines.push(meetLine);
    }
    return computeBounds(lines);
  }

  private downsample(points: CanvasPoint[], maxPts: number): CanvasPoint[] {
    if (points.length <= maxPts) {
      return points;
    }
    const out: CanvasPoint[] = [];
    const step: number = (points.length - 1) / (maxPts - 1);
    for (let i = 0; i < maxPts; i++) {
      const idx: number = Math.round(i * step);
      out.push(points[idx]);
    }
    return out;
  }

  private projectedDriverSamples(): CanvasPoint[] {
    if (this.driverLine.length === 0) {
      return [];
    }
    const b: PolylineBounds = this.bounds();
    const full: CanvasPoint[] = projectPolyline(this.driverLine, b, this.widthPx, this.heightPx);
    return this.downsample(full, 24);
  }

  private projectedPassengerSamples(): CanvasPoint[] {
    if (this.passengerLine.length === 0) {
      return [];
    }
    const b: PolylineBounds = this.bounds();
    const full: CanvasPoint[] = projectPolyline(this.passengerLine, b, this.widthPx, this.heightPx);
    return this.downsample(full, 16);
  }

  private meetingProjected(): CanvasPoint {
    const b: PolylineBounds = this.bounds();
    const pts: CanvasPoint[] = projectPolyline(
      [new GeoPoint(this.meeting.lon, this.meeting.lat)],
      b,
      this.widthPx,
      this.heightPx
    );
    if (pts.length > 0) {
      return pts[0];
    }
    return new CanvasPoint(this.widthPx / 2, this.heightPx / 2);
  }

  build() {
    Stack() {
      ForEach(this.projectedDriverSamples(), (p: CanvasPoint, idx: number) => {
        Circle({ width: idx === 0 ? 8 : 4, height: idx === 0 ? 8 : 4 })
          .fill(idx === 0 ? AppTheme.accent : AppTheme.link)
          .position({ x: p.x - (idx === 0 ? 4 : 2), y: p.y - (idx === 0 ? 4 : 2) })
      }, (p: CanvasPoint, idx: number) => `ld-${idx}-${p.x.toFixed(1)}-${p.y.toFixed(1)}`)

      ForEach(this.projectedPassengerSamples(), (p: CanvasPoint, idx: number) => {
        Circle({ width: 4, height: 4 })
          .fill(AppTheme.warn)
          .opacity(0.95)
          .position({ x: p.x - 2, y: p.y - 2 })
      }, (p: CanvasPoint, idx: number) => `lp-${idx}-${p.x.toFixed(1)}-${p.y.toFixed(1)}`)

      if (this.meeting.lon !== 0 || this.meeting.lat !== 0) {
        Circle({ width: 12, height: 12 })
          .fill('#EF4444')
          .position({
            x: this.meetingProjected().x - 6,
            y: this.meetingProjected().y - 6
          })
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .borderRadius(16)
  }
}
