/**
 * Agent chat UI — Mode A/B tool loop or Mode C offline engine explanations.
 */

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AppSettings } from '../common/AppSettings';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
import { StageBackground } from '../common/GlassChrome';
import { formatReplyForBubble } from '../common/ReplyFormat';
import {
  dataSourceLabelZh,
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
import { AgentOrchestrator } from '../services/agent/AgentOrchestrator';
import { AgentTurnResult, ToolTraceEntry } from '../services/agent/AgentTypes';
import { MapProvider, PlanningService } from '../services/map/MapProvider';
import { FixtureCatalog, FixtureScenario } from '../services/planning/FixtureCatalog';
import { SettingsStore } from '../services/settings/SettingsStore';
import { TripSessionStore } from '../services/session/TripSessionStore';
import { ShareService } from '../services/session/ShareService';
import { MapLinkService } from '../services/map/MapLinkService';

class ChatBubble {
  id: string = '';
  role: string = 'assistant'; // user | assistant | system
  text: string = '';
  hasPlans: boolean = false;
}

class PlanMiniCard {
  id: string = '';
  title: string = '';
  detail: string = '';
  recommended: boolean = false;
  selected: boolean = false;
}

@Entry
@Component
struct ChatPage {
  @State settings: AppSettings = new AppSettings();
  @State fixtureId: string = 'xian-demo-1';
  @State fixtureTitle: string = '西安：高新 → 钟楼';
  @State city: string = '西安';
  @State driverName: string = '司机起点';
  @State passengerName: string = '乘客位置';
  @State driverLon: number = 108.8905;
  @State driverLat: number = 34.2324;
  @State passengerLon: number = 108.9465;
  @State passengerLat: number = 34.2610;
  @State allowWalk: boolean = true;
  @State allowBike: boolean = true;
  @State allowTransit: boolean = true;
  @State avoidTransit: boolean = false;
  @State maxWalkMin: number = 12;
  @State composer: string = '';
  @State bubbles: ChatBubble[] = [];
  @State planCards: PlanMiniCard[] = [];
  @State selectedPlanId: string = '';
  @State dataSourceBadge: string = '';
  @State busy: boolean = false;
  @State statusLine: string = '离线引擎随时可用';
  @State showTrace: boolean = false;
  @State traceLines: string[] = [];
  @State modeLabel: string = 'Offline';
  @State lastRec: RecommendationSet | null = null;
  @State confirming: boolean = false;
  private orch: AgentOrchestrator | null = null;
  private msgSeq: number = 0;

  aboutToAppear(): void {
    this.bootstrap();
  }

  aboutToDisappear(): void {
    if (this.orch !== null) {
      this.orch.cancel();
    }
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
    this.modeLabel = this.settings.modeLabel();
    this.applyFixture(FixtureCatalog.byId(this.fixtureId));
    this.resetOrchestrator();
    this.pushSystem(
      '你好，我是会合助手。用快捷语或描述约束即可规划。' +
        '无 Key 时用本地引擎估算。'
    );
    this.statusLine = this.settings.llmConfigured()
      ? `LLM ${this.settings.modeLabel()} · ${this.settings.llmModel}`
      : `LLM Offline · 引擎估算`;
  }

  private resetOrchestrator(): void {
    const provider: MapProvider = PlanningService.createProvider(this.settings.mapWebKey);
    this.orch = new AgentOrchestrator(this.settings, this.buildScenario(), provider);
  }

  private applyFixture(fix: FixtureScenario): void {
    this.fixtureId = fix.id;
    this.fixtureTitle = fix.title;
    this.city = fix.city;
    this.driverLon = fix.driver.lon;
    this.driverLat = fix.driver.lat;
    this.driverName = fix.driver.name;
    this.passengerLon = fix.passenger.lon;
    this.passengerLat = fix.passenger.lat;
    this.passengerName = fix.passenger.name;
    if (fix.constraints.maxPassengerWalkMin >= 0) {
      this.maxWalkMin = fix.constraints.maxPassengerWalkMin;
    }
    this.avoidTransit = fix.constraints.avoidTransit;
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
    s.driver = new NamedPoint(this.driverLon, this.driverLat, this.driverName, '');
    s.passenger = new NamedPoint(this.passengerLon, this.passengerLat, this.passengerName, '');
    s.constraints.allowedModes = this.buildAllowedModes();
    s.constraints.avoidTransit = this.avoidTransit;
    s.constraints.maxPassengerWalkMin = this.maxWalkMin;
    return s;
  }

  private nextId(prefix: string): string {
    this.msgSeq += 1;
    return `${prefix}-${this.msgSeq}`;
  }

  private pushSystem(text: string): void {
    const b: ChatBubble = new ChatBubble();
    b.id = this.nextId('sys');
    b.role = 'system';
    b.text = text;
    this.bubbles = this.bubbles.concat([b]);
  }

  private pushUser(text: string): void {
    const b: ChatBubble = new ChatBubble();
    b.id = this.nextId('u');
    b.role = 'user';
    b.text = text;
    this.bubbles = this.bubbles.concat([b]);
  }

  private pushAssistant(text: string, hasPlans: boolean): void {
    const b: ChatBubble = new ChatBubble();
    b.id = this.nextId('a');
    b.role = 'assistant';
    b.text = formatReplyForBubble(text);
    b.hasPlans = hasPlans;
    this.bubbles = this.bubbles.concat([b]);
  }

  private applyRecommendation(rec: RecommendationSet, selectedPlanId: string): void {
    this.lastRec = rec;
    this.dataSourceBadge = dataSourceLabelZh(rec.dataSource);
    const cards: PlanMiniCard[] = [];

    const stay: StayPutSuggestion = rec.stayPut;
    const stayCard: PlanMiniCard = new PlanMiniCard();
    stayCard.id = 'stayPut';
    stayCard.title = '原地等待';
    stayCard.detail = `司机约 ${stay.driverEtaMin.toFixed(0)} 分钟`;
    stayCard.recommended = stay.recommended;
    stayCard.selected = selectedPlanId === 'stayPut';
    cards.push(stayCard);

    for (let i = 0; i < rec.suggestions.length; i++) {
      const s: Suggestion = rec.suggestions[i];
      const c: PlanMiniCard = new PlanMiniCard();
      c.id = `suggestion:${i}`;
      c.title = `${modeLabelZh(s.mode)} · ${s.completionMin.toFixed(0)} 分`;
      c.detail =
        `乘客 ${s.passengerEtaMin.toFixed(0)} 分 · 司机 ${s.driverEtaMin.toFixed(0)} 分` +
          (s.driverSavedMin > 0.4 ? ` · 省 ${s.driverSavedMin.toFixed(0)}` : '');
      c.recommended = s.recommended;
      c.selected = selectedPlanId === c.id;
      cards.push(c);
    }
    // Prefer engine recommended if model id empty
    let pick: string = selectedPlanId;
    if (pick.length === 0) {
      for (let i = 0; i < cards.length; i++) {
        if (cards[i].recommended) {
          pick = cards[i].id;
          break;
        }
      }
      if (pick.length === 0 && cards.length > 0) {
        pick = cards[0].id;
      }
    }
    for (let i = 0; i < cards.length; i++) {
      cards[i].selected = cards[i].id === pick;
    }
    this.selectedPlanId = pick;
    this.planCards = cards;
    TripSessionStore.beginPlanning(this.buildScenario(), rec, pick);
  }

  private applyTrace(entries: ToolTraceEntry[]): void {
    const lines: string[] = [];
    for (let i = 0; i < entries.length; i++) {
      const t: ToolTraceEntry = entries[i];
      const flag: string = t.ok ? '✓' : '✗';
      let line: string = `${flag} ${t.name} · ${t.durationMs}ms · ${t.summary}`;
      if (t.error.length > 0) {
        line = `${line} · ${t.error}`;
      }
      lines.push(line);
    }
    this.traceLines = lines;
  }

  private async onSend(textOverride: string = ''): Promise<void> {
    if (this.busy) {
      return;
    }
    const text: string = textOverride.length > 0 ? textOverride : this.composer.trim();
    if (text.length === 0) {
      return;
    }
    this.composer = '';
    this.busy = true;
    this.statusLine = '正在规划…';
    this.pushUser(text);
    try {
      this.resetOrchestrator();
      if (this.orch === null) {
        this.pushAssistant('编排器未就绪', false);
        return;
      }
      const turn: AgentTurnResult = await this.orch.handleUserTurn(text);
      this.applyTrace(turn.toolTrace);
      if (turn.recommendation !== null) {
        this.applyRecommendation(turn.recommendation, turn.selectedPlanId);
        this.pushAssistant(turn.replyText, true);
      } else {
        this.pushAssistant(turn.replyText, false);
      }
      if (turn.usedLlm && !turn.offlineFallback) {
        this.statusLine = `LLM 完成 · ${this.dataSourceBadge}`;
      } else {
        this.statusLine = `离线引擎 · ${this.dataSourceBadge.length > 0 ? this.dataSourceBadge : '估算'}`;
      }
    } catch (e) {
      const errObj: Object = e as Object;
      this.pushAssistant(`出错了：${errObj}`, false);
      this.statusLine = '出错';
    } finally {
      this.busy = false;
    }
  }

  private onSelectPlan(id: string): void {
    if (id.length === 0 || this.planCards.length === 0) {
      return;
    }
    // Drive UI from selectedPlanId (same pattern as PlanPage) so @Builder re-renders.
    this.selectedPlanId = id;
    const next: PlanMiniCard[] = [];
    for (let i = 0; i < this.planCards.length; i++) {
      const c: PlanMiniCard = this.planCards[i];
      const copy: PlanMiniCard = new PlanMiniCard();
      copy.id = c.id;
      copy.title = c.title;
      copy.detail = c.detail;
      copy.recommended = c.recommended;
      copy.selected = c.id === id;
      next.push(copy);
    }
    this.planCards = next;
    TripSessionStore.selectPlan(id);
    promptAction.showToast({
      message: id === 'stayPut' ? '已选择：原地等待' : `已选择：${id}`,
      duration: 1200
    });
  }

  private async onConfirmLock(): Promise<void> {
    if (this.confirming) {
      return;
    }
    if (this.lastRec === null || this.selectedPlanId.length === 0) {
      promptAction.showToast({ message: '请先生成并选择方案', duration: 1800 });
      return;
    }
    this.confirming = true;
    try {
      if (TripSessionStore.getPlanning() === null) {
        TripSessionStore.beginPlanning(this.buildScenario(), this.lastRec, this.selectedPlanId);
      } else {
        TripSessionStore.selectPlan(this.selectedPlanId);
      }
      let meetName: string = '';
      if (this.selectedPlanId === 'stayPut') {
        meetName = this.lastRec.stayPut.meetingPoint.name;
      } else if (this.selectedPlanId.indexOf('suggestion:') === 0) {
        const idx: number = Number(this.selectedPlanId.substring('suggestion:'.length));
        if (!isNaN(idx) && idx >= 0 && idx < this.lastRec.suggestions.length) {
          meetName = this.lastRec.suggestions[idx].meetingPoint.name;
        }
      }
      const locked: TripSession | null = TripSessionStore.confirm(this.selectedPlanId, meetName, '');
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

  private async onShareSelected(): Promise<void> {
    if (this.lastRec === null) {
      promptAction.showToast({ message: '请先生成方案', duration: 1800 });
      return;
    }
    const text: string = ShareService.buildShareTextFromRec(this.lastRec, this.selectedPlanId);
    await ShareService.copyText(text);
  }

  private async onOpenMapSelected(): Promise<void> {
    if (this.lastRec === null) {
      promptAction.showToast({ message: '请先生成方案', duration: 1800 });
      return;
    }
    let lon: number = this.lastRec.stayPut.meetingPoint.lon;
    let lat: number = this.lastRec.stayPut.meetingPoint.lat;
    let name: string = this.lastRec.stayPut.meetingPoint.name;
    if (this.selectedPlanId.indexOf('suggestion:') === 0) {
      const idx: number = Number(this.selectedPlanId.substring('suggestion:'.length));
      if (!isNaN(idx) && idx >= 0 && idx < this.lastRec.suggestions.length) {
        lon = this.lastRec.suggestions[idx].meetingPoint.lon;
        lat = this.lastRec.suggestions[idx].meetingPoint.lat;
        name = this.lastRec.suggestions[idx].meetingPoint.name;
      }
    }
    await MapLinkService.openMeeting(
      this.hostContext(),
      lon,
      lat,
      name.length > 0 ? name : '会合点',
      this.settings.mapApp
    );
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开设置', duration: 2000 });
    });
  }

  private openPlanForm(): void {
    router.pushUrl({ url: 'pages/PlanPage' }).catch(() => {
      promptAction.showToast({ message: '无法打开规划页', duration: 2000 });
    });
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
            router.back();
          })

          Column({ space: 2 }) {
            Text('智能助手')
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

          Button('轨迹', { type: ButtonType.Capsule })
            .fontSize(12)
            .height(30)
            .backgroundColor(AppTheme.glassBgLight)
            .fontColor(AppTheme.ink)
            .border({ width: 1, color: AppTheme.glassBorder })
            .onClick(() => {
              this.showTrace = !this.showTrace;
            })
        }
        .width('100%')
        .padding({ left: 8, right: 12, top: AppLayout.headerTop(), bottom: 6 })

        // fixture chips
        Scroll() {
          Row({ space: 8 }) {
            this.fixtureChip('xian-demo-1', '西安示例')
            this.fixtureChip('shanghai-demo-1', '上海示例')
            Button('表单规划', { type: ButtonType.Capsule })
              .fontSize(12)
              .height(30)
              .backgroundColor(AppTheme.glassBgLight)
              .fontColor(AppTheme.ink)
              .border({ width: 1, color: AppTheme.glassBorder })
              .onClick(() => {
                this.openPlanForm();
              })
            Button('设置', { type: ButtonType.Capsule })
              .fontSize(12)
              .height(30)
              .backgroundColor(AppTheme.glassBgLight)
              .fontColor(AppTheme.ink)
              .border({ width: 1, color: AppTheme.glassBorder })
              .onClick(() => {
                this.openSettings();
              })
          }
          .padding({ left: 14, right: 14 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(40)

        Text(this.fixtureTitle)
          .fontSize(12)
          .fontColor(AppTheme.inkMuted)
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 4 })

        if (this.showTrace) {
          Column({ space: 4 }) {
            Text('决策过程（工具轨迹）')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.link)
              .width('100%')
            if (this.traceLines.length === 0) {
              Text('暂无工具调用')
                .fontSize(12)
                .fontColor(AppTheme.inkSoft)
            } else {
              ForEach(this.traceLines, (line: string, idx: number) => {
                Text(line)
                  .fontSize(11)
                  .fontColor(AppTheme.inkMuted)
                  .width('100%')
              }, (line: string, idx: number) => `tr-${idx}-${line.length}`)
            }
          }
          .width('100%')
          .padding(12)
          .margin({ left: 14, right: 14, bottom: 6 })
          .borderRadius(14)
          .backgroundColor(AppTheme.glassBgStrong)
          .border({ width: 1, color: AppTheme.glassBorder })
          .backdropBlur(AppTheme.blurSoft)
        }

        // messages
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.bubbles, (b: ChatBubble) => {
              this.bubbleView(b)
            }, (b: ChatBubble) => b.id)

            if (this.planCards.length > 0) {
              Text('方案卡片（点选切换 · 数值来自引擎）')
                .fontSize(12)
                .fontColor(AppTheme.inkSoft)
                .width('100%')
                .margin({ top: 4 })

              ForEach(this.planCards, (c: PlanMiniCard) => {
                this.planCardView(c)
              }, (c: PlanMiniCard) => `${c.id}|${this.selectedPlanId}|${c.selected ? '1' : '0'}`)

              Button(this.confirming ? '锁定中…' : '确认并锁定所选方案', { type: ButtonType.Capsule })
                .width('100%')
                .height(46)
                .margin({ top: 8 })
                .backgroundColor(AppTheme.success)
                .fontColor(Color.White)
                .enabled(!this.confirming && !this.busy)
                .onClick(() => {
                  this.onConfirmLock();
                })

              Row({ space: 8 }) {
                Button('复制分享', { type: ButtonType.Capsule })
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor('#BF5AF2')
                  .fontColor(Color.White)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.onShareSelected();
                  })
                Button('打开地图', { type: ButtonType.Capsule })
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor(AppTheme.accent)
                  .fontColor(Color.White)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.onOpenMapSelected();
                  })
              }
              .width('100%')
              .margin({ top: 6 })

              Button('查看已锁定方案', { type: ButtonType.Capsule })
                .width('100%')
                .height(38)
                .margin({ top: 6 })
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(AppTheme.ink)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.openLockedPage();
                })
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 12, top: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)

        // quick prompts
        Scroll() {
          Row({ space: 8 }) {
            this.quickChip('帮我规划会合，我可以骑车')
            this.quickChip('尽量少走路，不要公交')
            this.quickChip('乘客原地等待可以吗？')
          }
          .padding({ left: 14, right: 14 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(40)
        .margin({ bottom: 6 })

        // composer
        Row({ space: 8 }) {
          TextInput({ text: this.composer, placeholder: '描述约束或提问…' })
            .layoutWeight(1)
            .height(44)
            .borderRadius(14)
            .backgroundColor(AppTheme.fieldBg)
            .fontColor(AppTheme.ink)
            .placeholderColor(AppTheme.inkFaint)
            .border({ width: 1, color: AppTheme.lineStrong })
            .enabled(!this.busy)
            .onChange((v: string) => {
              this.composer = v;
            })
            .onSubmit(() => {
              this.onSend();
            })

          Button(this.busy ? '…' : '发送', { type: ButtonType.Capsule })
            .height(44)
            .width(72)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(AppTheme.accent)
            .fontColor(Color.White)
            .enabled(!this.busy)
            .onClick(() => {
              this.onSend();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 18, top: 6 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
  }

  @Builder
  fixtureChip(id: string, label: string) {
    Button(label, { type: ButtonType.Capsule })
      .fontSize(12)
      .height(30)
      .backgroundColor(this.fixtureId === id ? AppTheme.accent : AppTheme.glassBgLight)
      .fontColor(this.fixtureId === id ? Color.White : AppTheme.ink)
      .border({ width: 1, color: this.fixtureId === id ? AppTheme.lineFocus : AppTheme.glassBorder })
      .onClick(() => {
        this.applyFixture(FixtureCatalog.byId(id));
        this.resetOrchestrator();
        this.pushSystem(`已切换示例：${this.fixtureTitle}`);
      })
  }

  @Builder
  quickChip(text: string) {
    Button(text, { type: ButtonType.Capsule })
      .fontSize(11)
      .height(30)
      .backgroundColor(AppTheme.accentSoft)
      .fontColor(AppTheme.link)
      .border({ width: 1, color: AppTheme.lineFocus })
      .enabled(!this.busy)
      .onClick(() => {
        this.onSend(text);
      })
  }

  @Builder
  bubbleView(b: ChatBubble) {
    // Fixed side gutters + layoutWeight bubble: avoids % width + Blank fighting
    // (unconstrained Text measuring past the screen edge).
    Row() {
      if (b.role === 'user') {
        Blank().width(40)
      } else {
        Blank().width(0)
      }

      Column({ space: 4 }) {
        Text(b.role === 'user' ? '你' : (b.role === 'system' ? '系统' : '会合助手'))
          .fontSize(10)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
          .textAlign(b.role === 'user' ? TextAlign.End : TextAlign.Start)

        Text(b.text)
          .fontSize(14)
          .fontColor(AppTheme.ink)
          .fontWeight(FontWeight.Regular)
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(40)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
      }
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(16)
      .backgroundColor(b.role === 'user' ? AppTheme.accentSoft : AppTheme.glassBg)
      .border({
        width: 1,
        color: b.role === 'user' ? AppTheme.lineFocus : AppTheme.glassBorder
      })
      .backdropBlur(AppTheme.blurSoft)
      .clip(true)
      .alignItems(HorizontalAlign.Start)

      if (b.role === 'user') {
        Blank().width(0)
      } else {
        Blank().width(40)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 2, right: 2 })
  }

  @Builder
  planCardView(c: PlanMiniCard) {
    Column({ space: 4 }) {
      Row() {
        Text(c.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedPlanId === c.id ? Color.White : AppTheme.ink)
          .layoutWeight(1)
        if (c.recommended) {
          Text('推荐')
            .fontSize(10)
            .fontColor(this.selectedPlanId === c.id ? Color.White : AppTheme.link)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(999)
            .backgroundColor(this.selectedPlanId === c.id ? '#33FFFFFF' : AppTheme.accentSoft)
        }
      }
      .width('100%')
      Text(c.detail)
        .fontSize(12)
        .fontColor(this.selectedPlanId === c.id ? '#E6FFFFFF' : AppTheme.inkMuted)
        .width('100%')
      Text(c.id)
        .fontSize(10)
        .fontColor(this.selectedPlanId === c.id ? '#B3FFFFFF' : AppTheme.inkSoft)
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor(this.selectedPlanId === c.id ? AppTheme.cardSelected : AppTheme.glassBgStrong)
    .border({
      width: this.selectedPlanId === c.id ? 2 : 1,
      color: this.selectedPlanId === c.id ? AppTheme.lineFocus : AppTheme.glassBorder
    })
    .backdropBlur(AppTheme.blurSoft)
    .opacity(1)
    .onClick(() => {
      this.onSelectPlan(c.id);
    })
  }
}
