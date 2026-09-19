import { privacyManager } from '@kit.AppGalleryKit';
import { BottomNavigation } from '../common/BottomNavigation';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  AppSettings,
  LLM_MODE_OFFLINE,
  LLM_MODE_PROXY,
  LLM_MODE_USER_KEY,
  LlmMode,
  MAP_APP_AMAP,
  MAP_APP_APPLE,
  MAP_APP_BAIDU,
  MAP_APP_BROWSER,
  MapAppChoice
} from '../common/AppSettings';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
import { StageBackground } from '../common/GlassChrome';
import { SettingsStore } from '../services/settings/SettingsStore';
import { LlmPingResult, OpenAiCompatibleClient } from '../services/llm/OpenAiCompatibleClient';

@Entry
@Component
struct SettingsPage {
  private async openPrivacy(): Promise<void> {
    let url: string = 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=2042833072528880704';
    try {
      const info: privacyManager.AppPrivacyMgmtInfo = privacyManager.getAppPrivacyMgmtInfo();
      for (const link of info.privacyInfo) {
        if (link.type === privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK && link.url.startsWith('https://')) {
          url = link.url;
          break;
        }
      }
    } catch (_) {
      // Direct installations may not yet have AppGallery privacy metadata.
    }
    try {
      await (getContext(this) as common.UIAbilityContext).startAbility({
        action: 'ohos.want.action.viewData', uri: url
      });
    } catch (_) {
      promptAction.showToast({ message: '暂时无法打开隐私声明，请稍后重试' });
    }
  }

  @State settings: AppSettings = new AppSettings();
  @State loaded: boolean = false;
  @State saving: boolean = false;
  @State pinging: boolean = false;
  @State statusText: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private hostContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private async reload(): Promise<void> {
    try {
      this.settings = await SettingsStore.load(this.hostContext());
      this.loaded = true;
      this.statusText = '设置仅保存在此设备';
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settings = new AppSettings();
      this.loaded = true;
      this.statusText = '加载失败，使用默认值';
    }
  }

  private async onSave(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      await SettingsStore.save(this.hostContext(), this.settings);
      this.statusText = '已保存到本机（不会上传）';
      promptAction.showToast({ message: '设置已保存', duration: 2000 });
    } catch (e) {
      const _ignored: Object = e as Object;
      this.statusText = '保存失败';
      promptAction.showToast({ message: '保存失败', duration: 2000 });
    } finally {
      this.saving = false;
    }
  }

  private async onTestLlm(): Promise<void> {
    if (this.pinging) {
      return;
    }
    this.pinging = true;
    this.statusText = '正在测试 LLM 连接…';
    try {
      // Persist draft so mode/url match what user sees
      await SettingsStore.save(this.hostContext(), this.settings);
      const client: OpenAiCompatibleClient = new OpenAiCompatibleClient(this.settings);
      const ping: LlmPingResult = await client.ping();
      this.statusText = ping.message;
      promptAction.showToast({
        message: ping.ok ? 'LLM 连接成功' : 'LLM 连接失败',
        duration: 2200
      });
    } catch (e) {
      const errObj: Object = e as Object;
      this.statusText = `测试异常：${errObj}`;
      promptAction.showToast({ message: '测试异常', duration: 2000 });
    } finally {
      this.pinging = false;
    }
  }

  private setMode(mode: LlmMode): void {
    const next: AppSettings = this.settings.clone();
    next.llmMode = mode;
    this.settings = next;
  }


  private setMapApp(app: MapAppChoice): void {
    const next: AppSettings = this.settings.clone();
    next.mapApp = app;
    this.settings = next;
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.link)
      .margin({ top: 16, bottom: 8 })
      .width('100%')
  }

  @Builder
  fieldLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(AppTheme.inkSoft)
      .margin({ bottom: 4, top: 6 })
      .width('100%')
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
          Text('设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

        }
        .width('100%')
        .padding({ left: 8, right: 8, top: AppLayout.headerTop(), bottom: 4 })

        if (!this.loaded) {
          Text('加载中…')
            .fontColor(AppTheme.inkMuted)
            .margin({ top: 40 })
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Column() {
                this.sectionTitle('默认地图应用')
                Column({ space: 8 }) {
                  this.mapAppRow(MAP_APP_AMAP, '高德地图 (AMap)')
                  this.mapAppRow(MAP_APP_APPLE, 'Apple 地图')
                  this.mapAppRow(MAP_APP_BAIDU, '百度地图')
                  this.mapAppRow(MAP_APP_BROWSER, '浏览器网页地图')
                }
                .width('100%')
                Text('确认会合后，使用此地图打开路线。')
                  .fontSize(11)
                  .fontColor(AppTheme.inkSoft)
                  .margin({ top: 6 })
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .borderRadius(AppTheme.radiusLg)
              .backgroundColor(AppTheme.glassBg)
              .backdropBlur(AppTheme.blurPanel)
              .border({ width: 1, color: AppTheme.glassBorder })
              .shadow({
                radius: 28,
                color: '#08000000',
                offsetX: 0,
                offsetY: 12
              })

              Column() {
                Button('隐私声明', { type: ButtonType.Capsule })
                  .width('100%').height(44).margin({ bottom: 16 })
                  .backgroundColor(AppTheme.accentSoft).fontColor(AppTheme.accent)
                  .onClick(() => { this.openPrivacy(); })

                this.sectionTitle('地图 Key')
                this.fieldLabel('Map Web Key（HTTP 路线 / POI · 高德 Web 服务）')
                TextInput({ text: this.settings.mapWebKey, placeholder: 'restapi.amap.com Web Key' })
                  .type(InputType.Password)
                  .height(46)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .fontColor(AppTheme.ink)
                  .placeholderColor(AppTheme.inkFaint)
                  .border({ width: 1, color: AppTheme.lineStrong })
                  .onChange((v: string) => {
                    this.settings.mapWebKey = v;
                  })
                Text('用于地点搜索和实时路线。网络不可用时，仍可使用离线估算。')
                  .fontSize(11)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')
                  .margin({ top: 4, bottom: 4 })

                this.sectionTitle('大模型（OpenAI 兼容）')
                this.fieldLabel('模式')
                Row({ space: 8 }) {
                  this.modeChip(LLM_MODE_OFFLINE, '离线')
                  this.modeChip(LLM_MODE_USER_KEY, '用户 Key')
                  this.modeChip(LLM_MODE_PROXY, '代理')
                }
                .width('100%')

                this.fieldLabel('Base URL')
                TextInput({ text: this.settings.llmBaseUrl, placeholder: 'https://api.deepseek.com' })
                  .height(46)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .fontColor(AppTheme.ink)
                  .placeholderColor(AppTheme.inkFaint)
                  .border({ width: 1, color: AppTheme.lineStrong })
                  .onChange((v: string) => {
                    this.settings.llmBaseUrl = v;
                  })
                this.fieldLabel('API Key')
                TextInput({ text: this.settings.llmApiKey, placeholder: 'sk-…（仅存本机）' })
                  .type(InputType.Password)
                  .height(46)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .fontColor(AppTheme.ink)
                  .placeholderColor(AppTheme.inkFaint)
                  .border({ width: 1, color: AppTheme.lineStrong })
                  .onChange((v: string) => {
                    this.settings.llmApiKey = v;
                  })
                this.fieldLabel('Model')
                TextInput({ text: this.settings.llmModel, placeholder: 'deepseek-chat' })
                  .height(46)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .fontColor(AppTheme.ink)
                  .placeholderColor(AppTheme.inkFaint)
                  .border({ width: 1, color: AppTheme.lineStrong })
                  .onChange((v: string) => {
                    this.settings.llmModel = v;
                  })
                this.fieldLabel('Proxy Base URL（Mode B）')
                TextInput({ text: this.settings.proxyBaseUrl, placeholder: 'http://127.0.0.1:8787' })
                  .height(46)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .fontColor(AppTheme.ink)
                  .placeholderColor(AppTheme.inkFaint)
                  .border({ width: 1, color: AppTheme.lineStrong })
                  .onChange((v: string) => {
                    this.settings.proxyBaseUrl = v;
                  })

                Text(this.statusText)
                  .fontSize(12)
                  .fontColor(AppTheme.inkMuted)
                  .margin({ top: 16 })
                  .width('100%')

                Button(this.pinging ? '测试中…' : '测试 LLM 连接', { type: ButtonType.Capsule })
                  .width('100%')
                  .height(44)
                  .margin({ top: 12 })
                  .backgroundColor(AppTheme.glassBgLight)
                  .fontColor(AppTheme.ink)
                  .border({ width: 1, color: AppTheme.glassBorder })
                  .enabled(!this.pinging && !this.saving)
                  .onClick(() => {
                    this.onTestLlm();
                  })

                Button(this.saving ? '保存中…' : '保存设置', { type: ButtonType.Capsule })
                  .width('100%')
                  .height(48)
                  .margin({ top: 10, bottom: 8 })
                  .backgroundColor(AppTheme.accent)
                  .fontColor(Color.White)
                  .border({ width: 1, color: '#59FFFFFF' })
                  .shadow({
                    radius: 20,
                    color: '#18007AFF',
                    offsetX: 0,
                    offsetY: 8
                  })
                  .enabled(!this.saving)
                  .onClick(() => {
                    this.onSave();
                  })
              }
              .width('100%')
              .padding(16)
              .borderRadius(AppTheme.radiusLg)
              .backgroundColor(AppTheme.glassBgStrong)
              .backdropBlur(AppTheme.blurPanel)
              .border({ width: 1, color: AppTheme.glassBorder })
              .shadow({
                radius: 28,
                color: '#08000000',
                offsetX: 0,
                offsetY: 12
              })
              .margin({ bottom: 28 })
            }
            .padding({ left: 16, right: 16, bottom: 24 })
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        BottomNavigation({ active: 'settings' })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
  }

  @Builder
  modeChip(mode: LlmMode, label: string) {
    Button(label, { type: ButtonType.Capsule })
      .fontSize(12)
      .height(32)
      .backgroundColor(this.settings.llmMode === mode ? AppTheme.accent : AppTheme.glassBgLight)
      .fontColor(this.settings.llmMode === mode ? Color.White : AppTheme.ink)
      .border({ width: 1, color: this.settings.llmMode === mode ? AppTheme.lineFocus : AppTheme.glassBorder })
      .onClick(() => {
        this.setMode(mode);
      })
  }


  @Builder
  mapAppRow(app: MapAppChoice, label: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppTheme.ink)
        .layoutWeight(1)
      Text(this.settings.mapApp === app ? '✓' : '·')
        .fontSize(14)
        .fontColor(this.settings.mapApp === app ? AppTheme.link : AppTheme.inkSoft)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(14)
    .backgroundColor(this.settings.mapApp === app ? AppTheme.accentSoft : AppTheme.fieldBg)
    .border({ width: 1, color: this.settings.mapApp === app ? AppTheme.lineFocus : AppTheme.line })
    .onClick(() => {
      this.setMapApp(app);
    })
  }
}
