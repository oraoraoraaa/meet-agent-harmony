import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import {
  CanvasPoint,
  computeBounds,
  PolylineBounds,
  projectPolyline
} from '../common/PolylineMath';
import { AppSettings } from '../common/AppSettings';
import {
  dataSourceLabelZh,
  GeoPoint,
  MODE_BICYCLE,
  MODE_TRANSIT,
  MODE_WALKING,
  MobilityMode,
  modeLabelZh,
  NamedPoint,
  RecommendationSet,
  Scenario,
  StayPutSuggestion,
  Suggestion
} from '../domain/Models';
import { MapProvider, PlanningService } from '../services/map/MapProvider';
import { FixtureCatalog, FixtureScenario } from '../services/planning/FixtureCatalog';
import { LocationService } from '../services/location/LocationService';
import { SettingsStore } from '../services/settings/SettingsStore';

class PlanCardModel {
  id: string = '';
  title: string = '';
  subtitle: string = '';
  rationale: string = '';
  recommended: boolean = false;
  kind: string = 'stayPut';
  suggestionIndex: number = -1;
  driverPolyline: GeoPoint[] = [];
  passengerPolyline: GeoPoint[] = [];
  meeting: NamedPoint = new NamedPoint();
}

@Entry
@Component
struct PlanPage {
  @State settings: AppSettings = new AppSettings();
  @State fixtureId: string = 'xian-demo-1';
  @State fixtureTitle: string = '西安：高新 → 钟楼';
  @State driverLonText: string = '108.8905';
  @State driverLatText: string = '34.2324';
  @State driverName: string = '司机起点';
  @State passengerLonText: string = '108.9465';
  @State passengerLatText: string = '34.2610';
  @State passengerName: string = '乘客位置';
  @State city: string = '西安';
  @State allowWalk: boolean = true;
  @State allowBike: boolean = true;
  @State allowTransit: boolean = true;
  @State avoidTransit: boolean = false;
  @State maxWalkMin: number = 12;
  @State planning: boolean = false;
  @State statusText: string = '选择示例或填写坐标后点击「开始规划」';
  @State errorText: string = '';
  @State hasResult: boolean = false;
  @State dataSourceBadge: string = '';
  @State cards: PlanCardModel[] = [];
  @State selectedCardId: string = '';
  @State previewDriver: GeoPoint[] = [];
  @State previewPassenger: GeoPoint[] = [];
  @State previewMeeting: NamedPoint = new NamedPoint();
  @State mapW: number = 320;
  @State mapH: number = 200;
  @State settingsLoaded: boolean = false;

  aboutToAppear(): void {
    this.reloadSettings();
    this.applyFixture(FixtureCatalog.byId(this.fixtureId));
  }

  private hostContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private async reloadSettings(): Promise<void> {
    try {
      this.settings = await SettingsStore.load(this.hostContext());
      this.settingsLoaded = true;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settings = new AppSettings();
      this.settingsLoaded = true;
    }
  }

  private applyFixture(fix: FixtureScenario): void {
    this.fixtureId = fix.id;
    this.fixtureTitle = fix.title;
    this.city = fix.city;
    this.driverLonText = `${fix.driver.lon}`;
    this.driverLatText = `${fix.driver.lat}`;
    this.driverName = fix.driver.name;
    this.passengerLonText = `${fix.passenger.lon}`;
    this.passengerLatText = `${fix.passenger.lat}`;
    this.passengerName = fix.passenger.name;
    if (fix.constraints.maxPassengerWalkMin >= 0) {
      this.maxWalkMin = fix.constraints.maxPassengerWalkMin;
    } else {
      this.maxWalkMin = 12;
    }
    this.avoidTransit = fix.constraints.avoidTransit;
    this.statusText = fix.narrationZh;
  }

  private parseCoord(text: string, fallback: number): number {
    const v: number = Number(text);
    if (isNaN(v)) {
      return fallback;
    }
    return v;
  }

  private buildAllowedModes(): MobilityMode[] {
    const modes: MobilityMode[] = [];
    if (this.allowWalk) {
      modes.push(MODE_WALKING);
    }
    if (this.allowBike) {
      modes.push(MODE_BICYCLE);
    }
    if (this.allowTransit && !this.avoidTransit) {
      modes.push(MODE_TRANSIT);
    }
    if (modes.length === 0) {
      modes.push(MODE_WALKING);
    }
    return modes;
  }

  private buildScenario(): Scenario {
    const s: Scenario = new Scenario();
    s.city = this.city;
    s.driver = new NamedPoint(
      this.parseCoord(this.driverLonText, 108.89),
      this.parseCoord(this.driverLatText, 34.23),
      this.driverName,
      ''
    );
    s.passenger = new NamedPoint(
      this.parseCoord(this.passengerLonText, 108.95),
      this.parseCoord(this.passengerLatText, 34.26),
      this.passengerName,
      ''
    );
    s.constraints.allowedModes = this.buildAllowedModes();
    s.constraints.avoidTransit = this.avoidTransit;
    s.constraints.maxPassengerWalkMin = this.maxWalkMin;
    return s;
  }

  private async onUseGpsDriver(): Promise<void> {
    try {
      const snap = await LocationService.readOnce(this.hostContext());
      if (snap.lat !== undefined && snap.lon !== undefined) {
        this.driverLatText = (snap.lat as number).toFixed(5);
        this.driverLonText = (snap.lon as number).toFixed(5);
        this.driverName = '当前位置';
        this.statusText = snap.message;
      } else {
        this.statusText = snap.message;
      }
    } catch (e) {
      const _ignored: Object = e as Object;
      this.statusText = '定位失败';
    }
  }

  private async onPlan(): Promise<void> {
    if (this.planning) {
      return;
    }
    this.planning = true;
    this.errorText = '';
    this.statusText = '正在估算路线与会合方案…';
    try {
      if (!this.settingsLoaded) {
        await this.reloadSettings();
      }
      const scenario: Scenario = this.buildScenario();
      const sameLon: boolean = Math.abs(scenario.driver.lon - scenario.passenger.lon) < 1e-7;
      const sameLat: boolean = Math.abs(scenario.driver.lat - scenario.passenger.lat) < 1e-7;
      if (sameLon && sameLat) {
        this.errorText = '司机与乘客坐标不能相同';
        this.statusText = '请调整坐标';
        this.planning = false;
        return;
      }
      const provider: MapProvider = PlanningService.createProvider(this.settings.mapWebKey);
      const rec: RecommendationSet = await PlanningService.plan(scenario, provider);
      this.applyRecommendation(rec);
      this.statusText = `规划完成 · ${dataSourceLabelZh(rec.dataSource)}`;
      this.hasResult = true;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.errorText = '规划失败，请重试';
      this.statusText = '规划出错';
      this.hasResult = false;
    } finally {
      this.planning = false;
    }
  }

  private applyRecommendation(rec: RecommendationSet): void {
    this.dataSourceBadge = dataSourceLabelZh(rec.dataSource);
    const cards: PlanCardModel[] = [];

    const stay: StayPutSuggestion = rec.stayPut;
    const stayCard: PlanCardModel = new PlanCardModel();
    stayCard.id = 'stayPut';
    stayCard.kind = 'stayPut';
    stayCard.title = stay.recommended ? '推荐 · 原地等待' : '原地等待';
    stayCard.subtitle =
      `司机 ${stay.driverEtaMin.toFixed(0)} 分钟 · 完成 ${stay.completionMin.toFixed(0)} 分钟`;
    stayCard.rationale = stay.rationale;
    stayCard.recommended = stay.recommended;
    stayCard.driverPolyline = stay.driverRoutePolyline;
    stayCard.passengerPolyline = [];
    stayCard.meeting = stay.meetingPoint;
    cards.push(stayCard);

    for (let i = 0; i < rec.suggestions.length; i++) {
      const s: Suggestion = rec.suggestions[i];
      const card: PlanCardModel = new PlanCardModel();
      card.id = `s-${i}-${s.mode}`;
      card.kind = 'suggestion';
      card.suggestionIndex = i;
      const recPrefix: string = s.recommended ? '推荐 · ' : '';
      card.title = `${recPrefix}乘客${modeLabelZh(s.mode)}`;
      let sub: string =
        `司机 ${s.driverEtaMin.toFixed(0)}′ · 乘客 ${s.passengerEtaMin.toFixed(0)}′ · 完成 ${s.completionMin.toFixed(0)}′`;
      if (s.driverSavedMin > 0.4) {
        sub = `${sub} · 省 ${s.driverSavedMin.toFixed(0)}′`;
      }
      card.subtitle = sub;
      card.rationale = s.rationale;
      card.recommended = s.recommended;
      card.driverPolyline = s.driverRoutePolyline;
      card.passengerPolyline = s.passengerPathPolyline;
      card.meeting = s.meetingPoint;
      cards.push(card);
    }

    this.cards = cards;
    let selectId: string = stayCard.id;
    for (let i = 0; i < cards.length; i++) {
      if (cards[i].recommended) {
        selectId = cards[i].id;
        break;
      }
    }
    this.selectCard(selectId);
  }

  private selectCard(id: string): void {
    this.selectedCardId = id;
    for (let i = 0; i < this.cards.length; i++) {
      const c: PlanCardModel = this.cards[i];
      if (c.id === id) {
        this.previewDriver = c.driverPolyline;
        this.previewPassenger = c.passengerPolyline;
        this.previewMeeting = c.meeting;
        break;
      }
    }
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开设置', duration: 2000 });
    });
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Normal }) {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor('#0F766E')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })

        Text('会合规划')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('设置', { type: ButtonType.Capsule })
          .fontSize(12)
          .height(30)
          .backgroundColor('#CCFBF1')
          .fontColor('#0F766E')
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 8, bottom: 4 })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Text('示例场景')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F766E')
              .width('100%')
            Row({ space: 8 }) {
              ForEach(FixtureCatalog.all(), (f: FixtureScenario) => {
                Button(f.title, { type: ButtonType.Capsule })
                  .fontSize(11)
                  .height(30)
                  .constraintSize({ maxWidth: 160 })
                  .backgroundColor(this.fixtureId === f.id ? '#0D9488' : '#E2E8F0')
                  .fontColor(this.fixtureId === f.id ? Color.White : '#334155')
                  .onClick(() => {
                    this.applyFixture(f);
                  })
              }, (f: FixtureScenario) => f.id)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Color.White)

          Column({ space: 8 }) {
            Text('起终点')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F766E')
              .width('100%')
            Text('司机经度 / 纬度')
              .fontSize(12)
              .fontColor('#64748B')
              .width('100%')
            Row({ space: 8 }) {
              TextInput({ text: this.driverLonText, placeholder: 'lon' })
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.driverLonText = v;
                })
              TextInput({ text: this.driverLatText, placeholder: 'lat' })
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.driverLatText = v;
                })
            }
            .width('100%')
            TextInput({ text: this.driverName, placeholder: '司机名称' })
              .onChange((v: string) => {
                this.driverName = v;
              })
            Button('用当前定位作为司机起点')
              .width('100%')
              .height(36)
              .backgroundColor('#CCFBF1')
              .fontColor('#0F766E')
              .onClick(() => {
                this.onUseGpsDriver();
              })

            Text('乘客经度 / 纬度')
              .fontSize(12)
              .fontColor('#64748B')
              .margin({ top: 8 })
              .width('100%')
            Row({ space: 8 }) {
              TextInput({ text: this.passengerLonText, placeholder: 'lon' })
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.passengerLonText = v;
                })
              TextInput({ text: this.passengerLatText, placeholder: 'lat' })
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.passengerLatText = v;
                })
            }
            .width('100%')
            TextInput({ text: this.passengerName, placeholder: '乘客名称' })
              .onChange((v: string) => {
                this.passengerName = v;
              })
            TextInput({ text: this.city, placeholder: '城市（公交可选）' })
              .onChange((v: string) => {
                this.city = v;
              })
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Color.White)

          Column({ space: 8 }) {
            Text('乘客可用方式')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F766E')
              .width('100%')
            Row({ space: 8 }) {
              Button('步行', { type: ButtonType.Capsule })
                .fontSize(12)
                .height(32)
                .backgroundColor(this.allowWalk ? '#0D9488' : '#E2E8F0')
                .fontColor(this.allowWalk ? Color.White : '#334155')
                .onClick(() => {
                  this.allowWalk = !this.allowWalk;
                })
              Button('骑行', { type: ButtonType.Capsule })
                .fontSize(12)
                .height(32)
                .backgroundColor(this.allowBike ? '#0D9488' : '#E2E8F0')
                .fontColor(this.allowBike ? Color.White : '#334155')
                .onClick(() => {
                  this.allowBike = !this.allowBike;
                })
              Button('公交', { type: ButtonType.Capsule })
                .fontSize(12)
                .height(32)
                .backgroundColor(this.allowTransit ? '#0D9488' : '#E2E8F0')
                .fontColor(this.allowTransit ? Color.White : '#334155')
                .onClick(() => {
                  this.allowTransit = !this.allowTransit;
                })
            }
            .width('100%')
            Row() {
              Text('避免公交')
                .fontSize(14)
                .fontColor('#0F172A')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.avoidTransit })
                .selectedColor('#0D9488')
                .onChange((on: boolean) => {
                  this.avoidTransit = on;
                })
            }
            .width('100%')
            Text(`步行上限约 ${this.maxWalkMin.toFixed(0)} 分钟`)
              .fontSize(12)
              .fontColor('#64748B')
              .width('100%')
            Slider({
              value: this.maxWalkMin,
              min: 5,
              max: 25,
              step: 1,
              style: SliderStyle.OutSet
            })
              .selectedColor('#0D9488')
              .trackColor('#E2E8F0')
              .onChange((v: number) => {
                this.maxWalkMin = v;
              })
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Color.White)

          Button(this.planning ? '规划中…' : '开始规划')
            .width('100%')
            .height(46)
            .backgroundColor('#0D9488')
            .fontColor(Color.White)
            .enabled(!this.planning)
            .onClick(() => {
              this.onPlan();
            })

          Text(this.statusText)
            .fontSize(12)
            .fontColor('#64748B')
            .width('100%')

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(13)
              .fontColor('#DC2626')
              .width('100%')
          }

          if (this.hasResult) {
            Column({ space: 8 }) {
              Row() {
                Text('路线示意')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#0F766E')
                  .layoutWeight(1)
                Text(this.dataSourceBadge)
                  .fontSize(11)
                  .fontColor('#0F766E')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor('#CCFBF1')
                  .borderRadius(999)
              }
              .width('100%')

              Stack() {
                Column()
                  .width('100%')
                  .height(200)
                  .borderRadius(12)
                  .backgroundColor('#E2E8F0')
                PolylinePreview({
                  driverLine: this.previewDriver,
                  passengerLine: this.previewPassenger,
                  meeting: this.previewMeeting,
                  widthPx: this.mapW,
                  heightPx: this.mapH
                })
                  .width('100%')
                  .height(200)
              }
              .width('100%')
              .onAreaChange((_oldValue: Area, area: Area) => {
                const w: number = Number(area.width);
                if (!isNaN(w) && w > 0) {
                  this.mapW = w;
                }
              })

              Text('青绿=司机 · 琥珀=乘客 · 红点=会合点（示意，非真实道路）')
                .fontSize(11)
                .fontColor('#94A3B8')
                .width('100%')
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor(Color.White)

            Column({ space: 8 }) {
              Text('方案')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#0F766E')
                .width('100%')
              ForEach(this.cards, (card: PlanCardModel) => {
                Column({ space: 4 }) {
                  Text(card.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#0F172A')
                    .width('100%')
                  Text(card.subtitle)
                    .fontSize(12)
                    .fontColor('#0F766E')
                    .width('100%')
                  Text(card.rationale)
                    .fontSize(12)
                    .fontColor('#475569')
                    .width('100%')
                }
                .width('100%')
                .padding(12)
                .borderRadius(12)
                .backgroundColor(this.selectedCardId === card.id ? '#F0FDFA' : '#F8FAFC')
                .border({
                  width: this.selectedCardId === card.id ? 1.5 : 1,
                  color: this.selectedCardId === card.id ? '#0D9488' : '#E2E8F0'
                })
                .onClick(() => {
                  this.selectCard(card.id);
                })
              }, (card: PlanCardModel) => card.id)
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor(Color.White)
            .margin({ bottom: 28 })
          }
        }
        .padding({ left: 16, right: 16, bottom: 24, top: 4 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F5F9')
  }
}

@Component
struct PolylinePreview {
  @Prop driverLine: GeoPoint[] = [];
  @Prop passengerLine: GeoPoint[] = [];
  @Prop meeting: NamedPoint = new NamedPoint();
  @Prop widthPx: number = 320;
  @Prop heightPx: number = 200;

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
    return this.downsample(full, 28);
  }

  private projectedPassengerSamples(): CanvasPoint[] {
    if (this.passengerLine.length === 0) {
      return [];
    }
    const b: PolylineBounds = this.bounds();
    const full: CanvasPoint[] = projectPolyline(this.passengerLine, b, this.widthPx, this.heightPx);
    return this.downsample(full, 18);
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
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(12)
        .backgroundColor('#0F172A0D')

      ForEach(this.projectedDriverSamples(), (p: CanvasPoint, idx: number) => {
        Circle({ width: idx === 0 ? 8 : 4, height: idx === 0 ? 8 : 4 })
          .fill(idx === 0 ? '#0D9488' : '#14B8A6')
          .position({ x: p.x - (idx === 0 ? 4 : 2), y: p.y - (idx === 0 ? 4 : 2) })
      }, (p: CanvasPoint, idx: number) => `d-${idx}-${p.x.toFixed(1)}-${p.y.toFixed(1)}`)

      ForEach(this.projectedPassengerSamples(), (p: CanvasPoint, idx: number) => {
        Circle({ width: 4, height: 4 })
          .fill('#F59E0B')
          .opacity(0.9)
          .position({ x: p.x - 2, y: p.y - 2 })
      }, (p: CanvasPoint, idx: number) => `p-${idx}-${p.x.toFixed(1)}-${p.y.toFixed(1)}`)

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
    .borderRadius(12)
  }
}
