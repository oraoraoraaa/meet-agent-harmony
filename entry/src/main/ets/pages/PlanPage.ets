import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
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
  Suggestion,
  TripSession
} from '../domain/Models';
import { MapProvider, PlanningService } from '../services/map/MapProvider';
import { InteractiveMapView } from '../services/map/InteractiveMapView';
import { FixtureCatalog, FixtureScenario } from '../services/planning/FixtureCatalog';
import { SettingsStore } from '../services/settings/SettingsStore';
import { TripSessionStore } from '../services/session/TripSessionStore';
import { ShareService } from '../services/session/ShareService';
import { MapLinkService } from '../services/map/MapLinkService';
import { TripDraftStore } from '../services/session/TripDraftStore';
import { haversineM } from '../domain/Geo';

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
  @State statusText: string = '确认起终点后点击「开始路线优化」';
  @State errorText: string = '';
  @State hasResult: boolean = false;
  @State dataSourceBadge: string = '';
  @State cards: PlanCardModel[] = [];
  @State selectedCardId: string = '';
  @State previewDriver: GeoPoint[] = [];
  @State previewPassenger: GeoPoint[] = [];
  @State previewMeeting: NamedPoint = new NamedPoint();
  @State settingsLoaded: boolean = false;
  @State summaryTitle: string = '';
  @State summaryBody: string = '';
  @State showForm: boolean = true;
  @State lastRec: RecommendationSet | null = null;
  @State confirming: boolean = false;
  @State emptyHint: string = '';
  @State providerHint: string = '';
  @State resultMapToken: number = 0;
  /** Soft warn when points are city-scale far (emulator GPS). */
  @State distanceWarn: string = '';
  /** Meeting place label for UI (POI/address — never bare coords). */
  @State meetingPlaceLabel: string = '';
  /** Gates result map mount so Web gets non-zero size on first paint. */
  @State resultMapReady: boolean = false;

  aboutToAppear(): void {
    this.reloadSettings().then(() => {
      this.hydrateFromDraftOrFixture();
    });
  }

  private hostContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private hydrateFromDraftOrFixture(): void {
    // Prefer home-map draft. Never override a full draft with hardcoded fixtures.
    const d = TripDraftStore.get();
    if (d.hasDriver && d.hasPassenger) {
      this.driverLonText = `${d.driverLon}`;
      this.driverLatText = `${d.driverLat}`;
      this.driverName = d.driverName.length > 0 ? d.driverName : '司机起点';
      this.passengerLonText = `${d.passengerLon}`;
      this.passengerLatText = `${d.passengerLat}`;
      this.passengerName = d.passengerName.length > 0 ? d.passengerName : '乘客位置';
      if (d.city.length > 0) {
        this.city = d.city;
      }
      this.fixtureId = 'draft';
      this.fixtureTitle = '主页选点';
      this.statusText = '使用主页已选起终点 · 可调整方式后开始优化';
      this.refreshDistanceWarn();
      return;
    }
    if (d.hasDriver) {
      this.driverLonText = `${d.driverLon}`;
      this.driverLatText = `${d.driverLat}`;
      this.driverName = d.driverName.length > 0 ? d.driverName : '司机起点';
    }
    if (d.hasPassenger) {
      this.passengerLonText = `${d.passengerLon}`;
      this.passengerLatText = `${d.passengerLat}`;
      this.passengerName = d.passengerName.length > 0 ? d.passengerName : '乘客位置';
    }
    if (d.hasDriver || d.hasPassenger) {
      this.fixtureId = 'draft';
      this.fixtureTitle = '主页选点（不完整）';
      this.statusText = '主页选点不完整 — 请返回主页补全司机与乘客位置';
      this.refreshDistanceWarn();
      return;
    }
    // No draft: fall back to demo fixture once (first open without map pick).
    this.applyFixture(FixtureCatalog.byId(this.fixtureId));
    this.statusText = '未从主页带入选点 · 已载入示例（可返回主页重新选点）';
  }

  private refreshDistanceWarn(): void {
    const a: GeoPoint = new GeoPoint(
      this.parseCoord(this.driverLonText, 108.89),
      this.parseCoord(this.driverLatText, 34.23)
    );
    const b: GeoPoint = new GeoPoint(
      this.parseCoord(this.passengerLonText, 108.95),
      this.parseCoord(this.passengerLatText, 34.26)
    );
    const km: number = haversineM(a, b) / 1000;
    if (km > 80) {
      this.distanceWarn =
        `起终点直线约 ${km.toFixed(0)} km — ETA 会很大。模拟器请设同城坐标，或用地图/示例点。`;
    } else if (km < 0.05) {
      this.distanceWarn = '起终点过近或重合，请调整坐标。';
    } else {
      this.distanceWarn = '';
    }
  }

  private async reloadSettings(): Promise<void> {
    try {
      this.settings = await SettingsStore.load(this.hostContext());
      this.settingsLoaded = true;
      this.providerHint = PlanningService.describeProvider(
        this.settings.mapWebKey,
        this.settings.demoFixtures
      );
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settings = new AppSettings();
      this.settingsLoaded = true;
      this.providerHint = PlanningService.describeProvider('', true);
    }
  }

  private createMapProvider(): MapProvider {
    return PlanningService.createProvider(this.settings.mapWebKey, this.settings.demoFixtures);
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
    this.refreshDistanceWarn();
  }

  private parseCoord(text: string, fallback: number): number {
    const v: number = Number(text);
    if (isNaN(v)) {
      return fallback;
    }
    return v;
  }

  /** UI: show POI/address only — never bare coordinates. */
  private placeLabel(name: string): string {
    const n: string = name.trim();
    if (n.length === 0 || n === '地图选点' || n === '当前位置') {
      return '附近地点';
    }
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
          return head.length > 0 ? head : '附近地点';
        }
      }
    }
    if (n.indexOf(',') > 0) {
      const a: string = n.split(',')[0].trim();
      if (a.length > 0 && a.charAt(0) >= '0' && a.charAt(0) <= '9') {
        return '附近地点';
      }
    }
    return n;
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

  private async onPlan(): Promise<void> {
    if (this.planning) {
      return;
    }
    this.planning = true;
    this.errorText = '';
    this.emptyHint = '';
    this.statusText = this.settings.demoFixtures || this.settings.mapWebKey.trim().length === 0
      ? '正在估算路线与会合方案…'
      : '正在获取驾车路线…';
    try {
      if (!this.settingsLoaded) {
        await this.reloadSettings();
      }
      const scenario: Scenario = this.buildScenario();
      const passengerMissing: boolean =
        this.passengerLonText.trim().length === 0 || this.passengerLatText.trim().length === 0;
      if (passengerMissing) {
        this.errorText = '请填写乘客坐标';
        this.emptyHint = '缺少乘客点：填写经纬度、搜索地点或选择示例场景。';
        this.statusText = '缺少乘客点';
        this.planning = false;
        promptAction.showToast({ message: '缺少乘客点', duration: 1800 });
        return;
      }
      const sameLon: boolean = Math.abs(scenario.driver.lon - scenario.passenger.lon) < 1e-7;
      const sameLat: boolean = Math.abs(scenario.driver.lat - scenario.passenger.lat) < 1e-7;
      if (sameLon && sameLat) {
        this.errorText = '司机与乘客坐标不能相同';
        this.emptyHint = '起终点重合时无法生成会合方案，请调整坐标。';
        this.statusText = '请调整坐标';
        this.planning = false;
        promptAction.showToast({ message: '起终点不能相同', duration: 1800 });
        return;
      }
      this.refreshDistanceWarn();
      const distKm: number = haversineM(scenario.driver.toGeo(), scenario.passenger.toGeo()) / 1000;
      if (distKm > 120) {
        this.errorText = `起终点过远（约 ${distKm.toFixed(0)} km）`;
        this.emptyHint =
          '模拟器定位常落在默认城市外。请：① 选西安/上海示例 ② 主页地图点选 ③ 模拟器设同城坐标。';
        this.statusText = '距离过大 — 已阻止规划';
        this.planning = false;
        promptAction.showToast({ message: '距离过大，请用示例或地图选点', duration: 2500 });
        return;
      }
      // Soft mode: if key present but demoFixtures still ON, remind user.
      if (this.settings.demoFixtures && this.settings.mapWebKey.trim().length > 0) {
        this.statusText = '演示 Fixture 开启中 · 强制估算（设置里可关）…';
      } else if (!this.settings.demoFixtures && this.settings.mapWebKey.trim().length > 0) {
        this.statusText = '正在获取驾车路线与乘客路径…';
      }
      const provider: MapProvider = this.createMapProvider();
      const rec: RecommendationSet = await PlanningService.plan(scenario, provider);
      this.lastRec = rec;
      // Begin planning session (in-memory). Prefer engine recommended id.
      let preferredId: string = 'stayPut';
      if (rec.stayPut.recommended) {
        preferredId = 'stayPut';
      } else {
        for (let i = 0; i < rec.suggestions.length; i++) {
          if (rec.suggestions[i].recommended) {
            preferredId = `suggestion:${i}`;
            break;
          }
        }
      }
      TripSessionStore.beginPlanning(scenario, rec, preferredId);
      this.applyRecommendation(rec);
      if (rec.suggestions.length === 0 && !rec.stayPut.recommended) {
        this.emptyHint = '仅有原地等待可选（当前约束下无移动会合候选）。';
      } else if (rec.suggestions.length === 0) {
        this.emptyHint = '无移动会合候选，推荐乘客原地等待。';
      } else {
        this.emptyHint = '';
      }
      this.statusText = `规划完成 · ${dataSourceLabelZh(rec.dataSource)} · ${this.providerHint}`;
      this.hasResult = true;
      this.showForm = false;
      this.resultMapReady = false;
      this.resultMapToken = this.resultMapToken + 1;
      // Defer map mount: first frame after hasResult often has 0-height Web → blank until re-click.
      setTimeout(() => {
        this.bootstrapResultMap();
      }, 80);
      if (rec.dataSource === 'live_with_fallback') {
        promptAction.showToast({
          message: '部分模式回退估算（常见：公交/骑行权限）',
          duration: 2400
        });
      }
    } catch (e) {
      const _ignored: Object = e as Object;
      this.errorText = '规划失败，请重试或改用演示 Fixture';
      this.statusText = '规划出错';
      this.hasResult = false;
      this.emptyHint = '规划失败：请检查坐标 / 网络 / Map Web Key，或开启演示 Fixture。';
      promptAction.showToast({ message: '规划失败，可重试或开演示模式', duration: 2200 });
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

  private resultCenterLon(): number {
    if (this.previewMeeting.lon !== 0) {
      return this.previewMeeting.lon;
    }
    return (this.parseCoord(this.driverLonText, 108.89) + this.parseCoord(this.passengerLonText, 108.95)) / 2;
  }

  private resultCenterLat(): number {
    if (this.previewMeeting.lat !== 0) {
      return this.previewMeeting.lat;
    }
    return (this.parseCoord(this.driverLatText, 34.23) + this.parseCoord(this.passengerLatText, 34.26)) / 2;
  }

  private bootstrapResultMap(): void {
    this.resultMapReady = true;
    this.resultMapToken = this.resultMapToken + 1;
    // Second tick: some Web runtimes need a prop change after attach.
    setTimeout(() => {
      this.resultMapToken = this.resultMapToken + 1;
    }, 120);
  }

  private meetingLabelLooksRaw(name: string): boolean {
    const n: string = name.trim();
    if (n.length === 0) {
      return true;
    }
    if (n.indexOf('会合点') === 0) {
      return true;
    }
    if (n.indexOf(',') > 0) {
      const a: string = n.split(',')[0].trim();
      if (a.length > 0 && a.charAt(0) >= '0' && a.charAt(0) <= '9') {
        return true;
      }
    }
    return false;
  }

  private async refreshMeetingPlaceLabel(): Promise<void> {
    const meet: NamedPoint = this.previewMeeting;
    if (meet.lon === 0 && meet.lat === 0) {
      this.meetingPlaceLabel = '';
      return;
    }
    // Prefer existing good name/address
    if (!this.meetingLabelLooksRaw(meet.name) && meet.name.trim().length > 0) {
      this.meetingPlaceLabel = this.placeLabel(meet.name);
      return;
    }
    if (meet.address.trim().length > 0 && !this.meetingLabelLooksRaw(meet.address)) {
      this.meetingPlaceLabel = meet.address.trim();
      return;
    }
    try {
      const provider: MapProvider = this.createMapProvider();
      const label: string = await provider.reverseGeocode(new GeoPoint(meet.lon, meet.lat));
      if (label.trim().length > 0) {
        this.meetingPlaceLabel = label.trim();
        // Also stamp onto meeting for share/lock copy
        this.previewMeeting.name = label.trim();
        return;
      }
    } catch (e) {
      const _ignored: Object = e as Object;
    }
    this.meetingPlaceLabel = this.placeLabel(meet.name.length > 0 ? meet.name : '会合点附近');
  }

  private selectCard(id: string): void {
    this.selectedCardId = id;
    for (let i = 0; i < this.cards.length; i++) {
      const c: PlanCardModel = this.cards[i];
      if (c.id === id) {
        // New array refs so map @Prop sees change
        this.previewDriver = c.driverPolyline.slice();
        this.previewPassenger = c.passengerPolyline.slice();
        this.previewMeeting = c.meeting;
        this.summaryTitle = c.recommended ? '最快方案' : c.modeLabel;
        if (c.kind === 'stayPut') {
          this.summaryBody =
            `乘客原地等待；司机约 ${c.driverEtaMin.toFixed(0)} 分钟到达。`;
          TripSessionStore.selectPlan('stayPut');
        } else {
          const meetUi: string = this.placeLabel(
            c.meeting.name.length > 0 ? c.meeting.name : '会合点'
          );
          this.summaryBody =
            `乘客：${c.modeLabel}到 ${meetUi}\n` +
            `司机：约 ${c.driverEtaMin.toFixed(0)} 分钟` +
            (c.driverSavedMin > 0.4 ? `，节省约 ${c.driverSavedMin.toFixed(0)} 分钟车程` : '');
          if (c.suggestionIndex >= 0) {
            TripSessionStore.selectPlan(`suggestion:${c.suggestionIndex}`);
          }
        }
        this.resultMapToken = this.resultMapToken + 1;
        if (!this.resultMapReady && this.hasResult) {
          this.resultMapReady = true;
        }
        this.refreshMeetingPlaceLabel();
        break;
      }
    }
  }

  private currentPlanId(): string {
    for (let i = 0; i < this.cards.length; i++) {
      if (this.cards[i].id === this.selectedCardId) {
        const c: PlanCardModel = this.cards[i];
        if (c.kind === 'stayPut') {
          return 'stayPut';
        }
        if (c.suggestionIndex >= 0) {
          return `suggestion:${c.suggestionIndex}`;
        }
      }
    }
    return 'stayPut';
  }

  private modeIcon(modeKey: string): string {
    if (modeKey === MODE_WALKING || modeKey === 'walking') {
      return '🚶';
    }
    if (modeKey === MODE_BICYCLE || modeKey === 'bicycle') {
      return '🚲';
    }
    if (modeKey === MODE_TRANSIT || modeKey === 'transit') {
      return '🚌';
    }
    if (modeKey === 'stay') {
      return '🧍';
    }
    return '📍';
  }

  private mapCaption(): string {
    if (this.lastRec === null) {
      return '示意路线';
    }
    if (this.lastRec.dataSource === 'live') {
      return '引擎折线 · 实时路网';
    }
    if (this.lastRec.dataSource === 'live_with_fallback') {
      return '引擎折线 · 实时+估算';
    }
    return '示意路线 · 估算（非真实道路）';
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开设置', duration: 1800 });
    });
  }

  private async onShare(): Promise<void> {
    if (this.lastRec === null) {
      promptAction.showToast({ message: '请先规划方案', duration: 1800 });
      return;
    }
    const text: string = ShareService.buildShareTextFromRec(this.lastRec, this.currentPlanId());
    await ShareService.copyText(text);
  }

  private async onOpenMap(): Promise<void> {
    const meet: NamedPoint = this.previewMeeting;
    if (meet.lon === 0 && meet.lat === 0 && this.cards.length === 0) {
      promptAction.showToast({ message: '请先选择方案', duration: 1800 });
      return;
    }
    const name: string = meet.name.length > 0 ? meet.name : '会合点';
    await MapLinkService.openMeeting(
      this.hostContext(),
      meet.lon,
      meet.lat,
      name,
      this.settings.mapApp
    );
  }

  private async onConfirmLock(): Promise<void> {
    if (this.confirming) {
      return;
    }
    if (this.lastRec === null) {
      promptAction.showToast({ message: '请先规划方案', duration: 1800 });
      return;
    }
    this.confirming = true;
    try {
      // Ensure planning session exists (may have been cleared)
      if (TripSessionStore.getPlanning() === null) {
        TripSessionStore.beginPlanning(this.buildScenario(), this.lastRec, this.currentPlanId());
      } else {
        TripSessionStore.selectPlan(this.currentPlanId());
      }
      const meet: NamedPoint = this.previewMeeting;
      let meetName: string = meet.name;
      let meetAddress: string = meet.address;
      // Best-effort reverse-geocode label when estimate left name empty / coord-only.
      if (meetName.length === 0 || meetName === '会合点') {
        try {
          const provider: MapProvider = this.createMapProvider();
          const label: string = await provider.reverseGeocode(new GeoPoint(meet.lon, meet.lat));
          if (label.length > 0) {
            meetName = label;
            if (meetAddress.length === 0) {
              meetAddress = label;
            }
          }
        } catch (e) {
          const _ignored: Object = e as Object;
        }
      }
      const locked: TripSession | null = TripSessionStore.confirm(
        this.currentPlanId(),
        meetName,
        meetAddress
      );
      if (locked === null) {
        promptAction.showToast({ message: '锁定失败', duration: 1800 });
        return;
      }
      promptAction.showToast({ message: '方案已锁定', duration: 1500 });
      router.pushUrl({ url: 'pages/LockedSessionPage' }).catch(() => {
        promptAction.showToast({ message: '无法打开锁定页', duration: 2000 });
      });
    } finally {
      this.confirming = false;
    }
  }

  private onReplanForm(): void {
    TripSessionStore.replan();
    this.showForm = true;
    this.statusText = '已关闭锁定会话（如有），可调整约束后重新规划';
  }

  private openLockedPage(): void {
    router.pushUrl({ url: 'pages/LockedSessionPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开锁定页', duration: 2000 });
    });
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

          Text(this.hasResult && !this.showForm ? '优化结果' : '普通规划')
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
        .padding({ left: 8, right: 12, top: AppLayout.headerTop(), bottom: 8 })

        Scroll() {
          Column({ space: 12 }) {
            if (this.showForm || !this.hasResult) {
              this.formSection()
            }

            if (this.distanceWarn.length > 0) {
              Text(this.distanceWarn)
                .fontSize(12)
                .fontColor(AppTheme.warn)
                .width('100%')
                .padding({ left: 4, right: 4 })
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
      // Read-only origin/destination from home map draft
      Column({ space: 8 }) {
        Text('起终点（主页已选 · 只读）')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.link)
          .width('100%')
        Text('司机')
          .fontSize(12)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
        Text(this.placeLabel(this.driverName))
          .fontSize(14)
          .fontColor(AppTheme.ink)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(AppTheme.fieldBg)
          .border({ width: 1, color: AppTheme.lineStrong })
        Text('乘客')
          .fontSize(12)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
          .margin({ top: 4 })
        Text(this.placeLabel(this.passengerName))
          .fontSize(14)
          .fontColor(AppTheme.ink)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(AppTheme.fieldBg)
          .border({ width: 1, color: AppTheme.lineStrong })
        Text(this.city.length > 0 ? `城市 · ${this.city}` : '城市 · —')
          .fontSize(12)
          .fontColor(AppTheme.inkMuted)
          .width('100%')
        Text('如需改点，请返回主页地图重新选择。')
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

      if (this.providerHint.length > 0) {
        Text(this.providerHint)
          .fontSize(11)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
      }

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
      // map card — mount only when layout is ready (avoids blank Web on first paint)
      Column({ space: 8 }) {
        Stack() {
          if (this.resultMapReady) {
            InteractiveMapView({
              mapWebKey: this.settings.demoFixtures ? '' : this.settings.mapWebKey,
              pickRole: 'none',
              driverLon: this.parseCoord(this.driverLonText, 108.89),
              driverLat: this.parseCoord(this.driverLatText, 34.23),
              hasDriver: true,
              // Green pin = passenger origin (not meeting). Meeting is on polylines.
              passengerLon: this.parseCoord(this.passengerLonText, 108.95),
              passengerLat: this.parseCoord(this.passengerLatText, 34.26),
              hasPassenger: true,
              centerLon: this.resultCenterLon(),
              centerLat: this.resultCenterLat(),
              zoom: 13,
              title: this.mapCaption(),
              driverLine: this.previewDriver,
              passengerLine: this.previewPassenger,
              showTraffic: this.settings.demoFixtures ? false : true,
              allowRoleSwitch: false,
              showChrome: false,
              reloadToken: this.resultMapToken
            })
              .width('100%')
              .height(260)
              .key(`plan-map-${this.resultMapToken}-${this.selectedCardId}`)
          } else {
            Column() {
              Text('地图加载中…')
                .fontSize(13)
                .fontColor(AppTheme.inkMuted)
            }
            .width('100%')
            .height(260)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(AppTheme.mapPanel)
          }

          Column() {
            Text(this.selectedModeBadge())
              .fontSize(11)
              .fontColor(Color.White)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(AppTheme.accent)
              .borderRadius(999)
          }
          .position({ x: 10, y: 10 })
        }
        .width('100%')
        .height(260)
        .clip(true)
        .borderRadius(16)
        .border({ width: 1, color: AppTheme.glassBorder })
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

      // meeting point — solid dark glass only (no white/light fills)
      Column({ space: 8 }) {
        Text('会合地点')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.link)
          .width('100%')
        Column({ space: 4 }) {
          Text(
            this.meetingPlaceLabel.length > 0
              ? this.meetingPlaceLabel
              : this.placeLabel(
                this.previewMeeting.name.length > 0 ? this.previewMeeting.name : '会合点附近'
              )
          )
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.ink)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.previewMeeting.address.length > 0 &&
            this.previewMeeting.address !== this.meetingPlaceLabel) {
            Text(this.previewMeeting.address)
              .fontSize(12)
              .fontColor(AppTheme.inkMuted)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor('#E61A2030')
        .border({ width: 1, color: AppTheme.lineStrong })
      }
      .width('100%')
      .padding(14)
      .borderRadius(16)
      .backgroundColor('#F0121620')
      .border({ width: 1, color: AppTheme.glassBorder })

      // actions: confirm lock + share + maps
      Button(this.confirming ? '锁定中…' : '确认并锁定方案', { type: ButtonType.Capsule })
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.success)
        .fontColor(Color.White)
        .enabled(!this.confirming)
        .onClick(() => {
          this.onConfirmLock();
        })

      Row({ space: 10 }) {
        Button('复制分享', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(46)
          .backgroundColor('#BF5AF2')
          .fontColor(Color.White)
          .onClick(() => {
            this.onShare();
          })
        Button('在地图中打开', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(46)
          .backgroundColor(AppTheme.accent)
          .fontColor(Color.White)
          .onClick(() => {
            this.onOpenMap();
          })
      }
      .width('100%')

      if (this.emptyHint.length > 0) {
        Text(this.emptyHint)
          .fontSize(12)
          .fontColor(AppTheme.warn)
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Text('确认后方案锁定（v1 不自动改点）。分享复制文案；地图用设置中的应用或网页回退。')
        .fontSize(11)
        .fontColor(AppTheme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)

      Button('查看已锁定方案', { type: ButtonType.Capsule })
        .width('100%')
        .height(40)
        .backgroundColor(AppTheme.glassBgLight)
        .fontColor(AppTheme.ink)
        .border({ width: 1, color: AppTheme.glassBorder })
        .onClick(() => {
          this.openLockedPage();
        })

      Button('重新规划', { type: ButtonType.Capsule })
        .width('100%')
        .height(42)
        .backgroundColor(AppTheme.card)
        .fontColor(AppTheme.inkMuted)
        .border({ width: 1, color: AppTheme.glassBorder })
        .onClick(() => {
          this.onReplanForm();
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
