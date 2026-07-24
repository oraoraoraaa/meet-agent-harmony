import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import {
  CanvasPoint,
  computeBounds,
  PolylineBounds,
  projectPolyline
} from '../common/PolylineMath';
import { AppTheme } from '../common/AppTheme';
import { StageBackground } from '../common/GlassChrome';
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
  modeLabel: string = '';
  placeLine: string = '';
  totalMinText: string = '';
  saveLine: string = '';
  rationale: string = '';
  recommended: boolean = false;
  kind: string = 'stayPut';
  suggestionIndex: number = -1;
  modeKey: string = '';
  driverPolyline: GeoPoint[] = [];
  passengerPolyline: GeoPoint[] = [];
  meeting: NamedPoint = new NamedPoint();
  passengerEtaMin: number = 0;
  driverEtaMin: number = 0;
  driverSavedMin: number = 0;
  completionMin: number = 0;
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
  @State statusText: string = '选择示例后点击「开始优化」';
  @State errorText: string = '';
  @State hasResult: boolean = false;
  @State dataSourceBadge: string = '';
  @State cards: PlanCardModel[] = [];
  @State selectedCardId: string = '';
  @State previewDriver: GeoPoint[] = [];
  @State previewPassenger: GeoPoint[] = [];
  @State previewMeeting: NamedPoint = new NamedPoint();
  @State mapW: number = 320;
  @State mapH: number = 180;
  @State settingsLoaded: boolean = false;
  @State summaryTitle: string = '';
  @State summaryBody: string = '';
  @State showForm: boolean = true;

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
      this.showForm = false;
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
    stayCard.modeKey = 'stay';
    stayCard.modeLabel = '原地等待';
    stayCard.title = '原地等待';
    stayCard.placeLine = '等待司机直接来接你';
    stayCard.totalMinText = `${stay.completionMin.toFixed(0)} 分钟`;
    stayCard.saveLine = '基准';
    stayCard.rationale = stay.rationale;
    stayCard.recommended = stay.recommended;
    stayCard.driverPolyline = stay.driverRoutePolyline;
    stayCard.passengerPolyline = [];
    stayCard.meeting = stay.meetingPoint;
    stayCard.driverEtaMin = stay.driverEtaMin;
    stayCard.passengerEtaMin = 0;
    stayCard.completionMin = stay.completionMin;
    stayCard.driverSavedMin = 0;
    cards.push(stayCard);

    for (let i = 0; i < rec.suggestions.length; i++) {
      const s: Suggestion = rec.suggestions[i];
      const card: PlanCardModel = new PlanCardModel();
      card.id = `s-${i}-${s.mode}`;
      card.kind = 'suggestion';
      card.suggestionIndex = i;
      card.modeKey = s.mode;
      card.modeLabel = `${modeLabelZh(s.mode)} ${s.passengerEtaMin.toFixed(0)} 分钟`;
      card.title = card.modeLabel;
      const meetName: string = s.meetingPoint.name.length > 0 ? s.meetingPoint.name : '会合点';
      card.placeLine = `在 ${meetName} 会合`;
      card.totalMinText = `${s.completionMin.toFixed(0)} 分钟`;
      if (s.driverSavedMin > 0.4) {
        card.saveLine = `司机省 ${s.driverSavedMin.toFixed(0)} 分钟`;
      } else {
        card.saveLine = '节省有限';
      }
      card.rationale = s.rationale;
      card.recommended = s.recommended;
      card.driverPolyline = s.driverRoutePolyline;
      card.passengerPolyline = s.passengerPathPolyline;
      card.meeting = s.meetingPoint;
      card.driverEtaMin = s.driverEtaMin;
      card.passengerEtaMin = s.passengerEtaMin;
      card.completionMin = s.completionMin;
      card.driverSavedMin = s.driverSavedMin;
      cards.push(card);
    }

    // keep recommended first-ish: sort recommended to top but preserve relative order
    const ordered: PlanCardModel[] = [];
    for (let i = 0; i < cards.length; i++) {
      if (cards[i].recommended) {
        ordered.push(cards[i]);
      }
    }
    for (let i = 0; i < cards.length; i++) {
      if (!cards[i].recommended) {
        ordered.push(cards[i]);
      }
    }
    this.cards = ordered;

    let selectId: string = ordered.length > 0 ? ordered[0].id : '';
    for (let i = 0; i < ordered.length; i++) {
      if (ordered[i].recommended) {
        selectId = ordered[i].id;
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
        if (c.recommended) {
          this.summaryTitle = '最快方案';
        } else {
          this.summaryTitle = '备选方案';
        }
        if (c.kind === 'stayPut') {
          this.summaryBody =
            `乘客原地等待；司机约 ${c.driverEtaMin.toFixed(0)} 分钟到达。`;
        } else {
          this.summaryBody =
            `乘客：${c.modeLabel}到 ${c.meeting.name.length > 0 ? c.meeting.name : '会合点'}\n` +
            `司机：约 ${c.driverEtaMin.toFixed(0)} 分钟` +
            (c.driverSavedMin > 0.4 ? `，节省约 ${c.driverSavedMin.toFixed(0)} 分钟车程` : '');
        }
        break;
      }
    }
  }

  private modeIcon(modeKey: string): string {
    if (modeKey === MODE_WALKING) {
      return '🚶';
    }
    if (modeKey === MODE_BICYCLE) {
      return '🚲';
    }
    if (modeKey === MODE_TRANSIT) {
      return '🚌';
    }
    return '🧍';
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开设置', duration: 2000 });
    });
  }

  private onSharePlaceholder(): void {
    promptAction.showToast({ message: '分享 · 即将接入（Phase 3）', duration: 2000 });
  }

  private onOpenMapPlaceholder(): void {
    promptAction.showToast({ message: '在地图中打开 · 即将接入（Phase 3）', duration: 2000 });
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
            if (!this.showForm && this.hasResult) {
              this.showForm = true;
            } else {
              router.back();
            }
          })

          Text(this.hasResult && !this.showForm ? '优化结果' : '会合规划')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          if (this.hasResult && !this.showForm) {
            Text(this.dataSourceBadge.length > 0 ? this.dataSourceBadge : '估算')
              .fontSize(11)
              .fontColor(AppTheme.ink)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(AppTheme.glassBgLight)
              .borderRadius(999)
              .border({ width: 1, color: AppTheme.glassBorder })
              .backdropBlur(AppTheme.blurSoft)
          } else {
            Button('设置', { type: ButtonType.Capsule })
              .fontSize(12)
              .height(30)
              .backgroundColor(AppTheme.glassBgLight)
              .fontColor(AppTheme.ink)
              .border({ width: 1, color: AppTheme.glassBorder })
              .backdropBlur(AppTheme.blurSoft)
              .onClick(() => {
                this.openSettings();
              })
          }
        }
        .width('100%')
        .padding({ left: 8, right: 12, top: 10, bottom: 8 })

        Scroll() {
          Column({ space: 12 }) {
            if (this.showForm || !this.hasResult) {
              this.formSection()
            }

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(13)
                .fontColor(AppTheme.danger)
                .width('100%')
                .padding({ left: 4 })
            }

            if (this.hasResult) {
              this.resultsSection()
            } else {
              Text(this.statusText)
                .fontSize(12)
                .fontColor(AppTheme.inkMuted)
                .width('100%')
                .padding({ left: 4, bottom: 20 })
            }
          }
          .padding({ left: 14, right: 14, bottom: 28, top: 4 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
  }

  @Builder
  formSection() {
    Column({ space: 12 }) {
      // fixtures
      Column({ space: 8 }) {
        Text('示例场景')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.link)
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(FixtureCatalog.all(), (f: FixtureScenario) => {
            Button(f.title, { type: ButtonType.Capsule })
              .fontSize(11)
              .height(30)
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(this.fixtureId === f.id ? AppTheme.accent : AppTheme.glassBgLight)
              .fontColor(this.fixtureId === f.id ? Color.White : AppTheme.inkMuted)
              .onClick(() => {
                this.applyFixture(f);
              })
          }, (f: FixtureScenario) => f.id)
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .borderRadius(AppTheme.radiusMd)
      .backgroundColor(AppTheme.glassBg)
      .backdropBlur(AppTheme.blurPanel)
      .border({ width: 1, color: AppTheme.glassBorder })

      // points form
      Column({ space: 8 }) {
        Text('起终点')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.link)
          .width('100%')
        Text('司机经度 / 纬度')
          .fontSize(12)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
        Row({ space: 8 }) {
          TextInput({ text: this.driverLonText, placeholder: 'lon' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(12)
            .backgroundColor(AppTheme.fieldBg)
            .fontColor(AppTheme.ink)
            .placeholderColor(AppTheme.inkFaint)
            .border({ width: 1, color: AppTheme.lineStrong })
            .onChange((v: string) => {
              this.driverLonText = v;
            })
          TextInput({ text: this.driverLatText, placeholder: 'lat' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(12)
            .backgroundColor(AppTheme.fieldBg)
            .fontColor(AppTheme.ink)
            .placeholderColor(AppTheme.inkFaint)
            .border({ width: 1, color: AppTheme.lineStrong })
            .onChange((v: string) => {
              this.driverLatText = v;
            })
        }
        .width('100%')
        TextInput({ text: this.driverName, placeholder: '司机名称' })
          .height(44)
          .borderRadius(12)
          .backgroundColor(AppTheme.fieldBg)
          .fontColor(AppTheme.ink)
          .placeholderColor(AppTheme.inkFaint)
          .border({ width: 1, color: AppTheme.lineStrong })
          .onChange((v: string) => {
            this.driverName = v;
          })
        Button('用当前定位作为司机起点', { type: ButtonType.Capsule })
          .width('100%')
          .height(40)
          .backgroundColor(AppTheme.accent)
          .fontColor(Color.White)
          .border({ width: 1, color: '#59FFFFFF' })
          .onClick(() => {
            this.onUseGpsDriver();
          })

        Text('乘客经度 / 纬度')
          .fontSize(12)
          .fontColor(AppTheme.inkSoft)
          .margin({ top: 4 })
          .width('100%')
        Row({ space: 8 }) {
          TextInput({ text: this.passengerLonText, placeholder: 'lon' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(12)
            .backgroundColor(AppTheme.fieldBg)
            .fontColor(AppTheme.ink)
            .placeholderColor(AppTheme.inkFaint)
            .border({ width: 1, color: AppTheme.lineStrong })
            .onChange((v: string) => {
              this.passengerLonText = v;
            })
          TextInput({ text: this.passengerLatText, placeholder: 'lat' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(12)
            .backgroundColor(AppTheme.fieldBg)
            .fontColor(AppTheme.ink)
            .placeholderColor(AppTheme.inkFaint)
            .border({ width: 1, color: AppTheme.lineStrong })
            .onChange((v: string) => {
              this.passengerLatText = v;
            })
        }
        .width('100%')
        TextInput({ text: this.passengerName, placeholder: '乘客名称' })
          .height(44)
          .borderRadius(12)
          .backgroundColor(AppTheme.fieldBg)
          .fontColor(AppTheme.ink)
          .placeholderColor(AppTheme.inkFaint)
          .border({ width: 1, color: AppTheme.lineStrong })
          .onChange((v: string) => {
            this.passengerName = v;
          })
        TextInput({ text: this.city, placeholder: '城市（公交可选）' })
          .height(44)
          .borderRadius(12)
          .backgroundColor(AppTheme.fieldBg)
          .fontColor(AppTheme.ink)
          .placeholderColor(AppTheme.inkFaint)
          .border({ width: 1, color: AppTheme.lineStrong })
          .onChange((v: string) => {
            this.city = v;
          })
        Text('地点搜索 / 地图点选 · 即将接入')
          .fontSize(11)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .borderRadius(AppTheme.radiusMd)
      .backgroundColor(AppTheme.glassBg)
      .backdropBlur(AppTheme.blurPanel)
      .border({ width: 1, color: AppTheme.glassBorder })

      Column({ space: 8 }) {
        Text('乘客可用方式')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.link)
          .width('100%')
        Row({ space: 8 }) {
          Button('步行', { type: ButtonType.Capsule })
            .fontSize(12)
            .height(32)
            .backgroundColor(this.allowWalk ? AppTheme.accent : AppTheme.glassBgLight)
            .fontColor(AppTheme.ink)
            .onClick(() => {
              this.allowWalk = !this.allowWalk;
            })
          Button('骑行', { type: ButtonType.Capsule })
            .fontSize(12)
            .height(32)
            .backgroundColor(this.allowBike ? AppTheme.accent : AppTheme.glassBgLight)
            .fontColor(AppTheme.ink)
            .onClick(() => {
              this.allowBike = !this.allowBike;
            })
          Button('公交', { type: ButtonType.Capsule })
            .fontSize(12)
            .height(32)
            .backgroundColor(this.allowTransit ? AppTheme.accent : AppTheme.glassBgLight)
            .fontColor(AppTheme.ink)
            .onClick(() => {
              this.allowTransit = !this.allowTransit;
            })
        }
        .width('100%')
        Row() {
          Text('避免公交')
            .fontSize(14)
            .fontColor(AppTheme.ink)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.avoidTransit })
            .selectedColor(AppTheme.accent)
            .onChange((on: boolean) => {
              this.avoidTransit = on;
            })
        }
        .width('100%')
        Text(`步行上限约 ${this.maxWalkMin.toFixed(0)} 分钟`)
          .fontSize(12)
          .fontColor(AppTheme.inkMuted)
          .width('100%')
        Slider({
          value: this.maxWalkMin,
          min: 5,
          max: 25,
          step: 1,
          style: SliderStyle.OutSet
        })
          .selectedColor(AppTheme.accent)
          .trackColor(AppTheme.cardMuted)
          .onChange((v: number) => {
            this.maxWalkMin = v;
          })
      }
      .width('100%')
      .padding(14)
      .borderRadius(AppTheme.radiusMd)
      .backgroundColor(AppTheme.glassBg)
      .backdropBlur(AppTheme.blurPanel)
      .border({ width: 1, color: AppTheme.glassBorder })

      Button(this.planning ? '优化中…' : '开始路线优化', { type: ButtonType.Capsule })
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.accent)
        .fontColor(Color.White)
        .border({ width: 1, color: '#59FFFFFF' })
        .shadow({ radius: 20, color: '#590A84FF', offsetX: 0, offsetY: 8 })
        .enabled(!this.planning)
        .onClick(() => {
          this.onPlan();
        })

      if (this.hasResult) {
        Button('查看优化结果', { type: ButtonType.Capsule })
          .width('100%')
          .height(42)
          .backgroundColor(AppTheme.glassBg)
          .fontColor(AppTheme.ink)
          .border({ width: 1, color: AppTheme.glassBorder })
          .onClick(() => {
            this.showForm = false;
          })
      }
    }
    .width('100%')
  }

  @Builder
  resultsSection() {
    Column({ space: 12 }) {
      // map card
      Column({ space: 8 }) {
        Stack() {
          Column()
            .width('100%')
            .height(180)
            .borderRadius(16)
            .backgroundColor(AppTheme.mapPanel)
          PolylinePreview({
            driverLine: this.previewDriver,
            passengerLine: this.previewPassenger,
            meeting: this.previewMeeting,
            widthPx: this.mapW,
            heightPx: this.mapH
          })
            .width('100%')
            .height(180)
          Column() {
            Text(this.selectedModeBadge())
              .fontSize(11)
              .fontColor(Color.White)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(AppTheme.accent)
              .borderRadius(999)
          }
          .position({ x: 10, y: 10 })
          Text('示意路线 · 非真实道路')
            .fontSize(10)
            .fontColor(AppTheme.inkMuted)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#99000000')
            .borderRadius(8)
            .position({ x: 10, y: 150 })
        }
        .width('100%')
        .height(180)
        .clip(true)
        .borderRadius(16)
        .border({ width: 1, color: AppTheme.glassBorder })
        .onAreaChange((_oldValue: Area, area: Area) => {
          const w: number = Number(area.width);
          if (!isNaN(w) && w > 0) {
            this.mapW = w;
          }
        })
      }
      .width('100%')

      Text('推荐方案')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.inkMuted)
        .width('100%')

      ForEach(this.cards, (card: PlanCardModel) => {
        Row() {
          Text(this.modeIcon(card.modeKey))
            .fontSize(22)
            .width(36)
            .textAlign(TextAlign.Center)

          Column({ space: 3 }) {
            Row({ space: 6 }) {
              Text(card.modeLabel)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.selectedCardId === card.id ? Color.White : AppTheme.ink)
              if (card.recommended) {
                Text('最快方案')
                  .fontSize(10)
                  .fontColor(Color.White)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(AppTheme.accent)
                  .borderRadius(999)
              }
            }
            .width('100%')
            Text(card.placeLine)
              .fontSize(12)
              .fontColor(this.selectedCardId === card.id ? '#E8F1FF' : AppTheme.inkMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 8, right: 8 })

          Column({ space: 2 }) {
            Text(card.totalMinText)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedCardId === card.id ? Color.White : AppTheme.ink)
            Text(card.saveLine)
              .fontSize(11)
              .fontColor(this.selectedCardId === card.id ? '#D6E8FF' : AppTheme.inkMuted)
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding(14)
        .borderRadius(AppTheme.radiusMd)
        .backgroundColor(this.selectedCardId === card.id ? AppTheme.cardSelected : AppTheme.glassBgStrong)
        .backdropBlur(AppTheme.blurSoft)
        .border({
          width: 1,
          color: this.selectedCardId === card.id ? AppTheme.lineFocus : AppTheme.glassBorder
        })
        .onClick(() => {
          this.selectCard(card.id);
        })
      }, (card: PlanCardModel) => card.id)

      // summary card
      Column({ space: 6 }) {
        Text(this.summaryTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('100%')
        Text(this.summaryBody)
          .fontSize(13)
          .fontColor('#EAF2FF')
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(16)
      .backgroundColor(this.summaryTitle === '最快方案' ? AppTheme.accent : AppTheme.glassBgStrong)
      .border({ width: 1, color: AppTheme.glassBorder })

      // meeting point
      Column({ space: 8 }) {
        Text('会合地点')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.link)
          .width('100%')
        Column({ space: 4 }) {
          Text(this.previewMeeting.name.length > 0 ? this.previewMeeting.name : '会合点')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.ink)
            .width('100%')
          Text(
            this.previewMeeting.address.length > 0
              ? this.previewMeeting.address
              : `${this.previewMeeting.lat.toFixed(5)}, ${this.previewMeeting.lon.toFixed(5)}`
          )
            .fontSize(12)
            .fontColor(AppTheme.inkMuted)
            .width('100%')
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor(AppTheme.fieldBg)
        .border({ width: 1, color: AppTheme.lineStrong })
      }
      .width('100%')
      .padding(14)
      .borderRadius(16)
      .backgroundColor(AppTheme.glassBg)
      .backdropBlur(AppTheme.blurSoft)
      .border({ width: 1, color: AppTheme.glassBorder })

      // placeholder actions
      Row({ space: 10 }) {
        Button('分享', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(46)
          .backgroundColor('#BF5AF2')
          .fontColor(Color.White)
          .onClick(() => {
            this.onSharePlaceholder();
          })
        Button('在地图中打开', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(46)
          .backgroundColor(AppTheme.accent)
          .fontColor(Color.White)
          .onClick(() => {
            this.onOpenMapPlaceholder();
          })
      }
      .width('100%')

      Text('分享 / 打开地图 · Phase 3 接入 · 当前为占位')
        .fontSize(11)
        .fontColor(AppTheme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)

      Button('重新规划', { type: ButtonType.Capsule })
        .width('100%')
        .height(42)
        .backgroundColor(AppTheme.card)
        .fontColor(AppTheme.inkMuted)
        .border({ width: 1, color: AppTheme.glassBorder })
        .onClick(() => {
          this.showForm = true;
        })
    }
    .width('100%')
  }

  private selectedModeBadge(): string {
    for (let i = 0; i < this.cards.length; i++) {
      if (this.cards[i].id === this.selectedCardId) {
        const c: PlanCardModel = this.cards[i];
        if (c.recommended) {
          return `${c.modeLabel} · 推荐`;
        }
        return c.modeLabel;
      }
    }
    return '方案预览';
  }
}

@Component
struct PolylinePreview {
  @Prop driverLine: GeoPoint[] = [];
  @Prop passengerLine: GeoPoint[] = [];
  @Prop meeting: NamedPoint = new NamedPoint();
  @Prop widthPx: number = 320;
  @Prop heightPx: number = 180;

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
      ForEach(this.projectedDriverSamples(), (p: CanvasPoint, idx: number) => {
        Circle({ width: idx === 0 ? 8 : 4, height: idx === 0 ? 8 : 4 })
          .fill(idx === 0 ? AppTheme.accent : AppTheme.link)
          .position({ x: p.x - (idx === 0 ? 4 : 2), y: p.y - (idx === 0 ? 4 : 2) })
      }, (p: CanvasPoint, idx: number) => `d-${idx}-${p.x.toFixed(1)}-${p.y.toFixed(1)}`)

      ForEach(this.projectedPassengerSamples(), (p: CanvasPoint, idx: number) => {
        Circle({ width: 4, height: 4 })
          .fill(AppTheme.warn)
          .opacity(0.95)
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
    .borderRadius(16)
  }
}
