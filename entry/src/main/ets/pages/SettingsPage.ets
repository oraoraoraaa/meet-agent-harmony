import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import {
  AppLanguage,
  AppSettings,
  LANG_EN,
  LANG_ZH_CN,
  LLM_MODE_OFFLINE,
  LLM_MODE_PROXY,
  LLM_MODE_USER_KEY,
  LlmMode
} from '../common/AppSettings';
import { SettingsStore } from '../services/settings/SettingsStore';

@Entry
@Component
struct SettingsPage {
  @State settings: AppSettings = new AppSettings();
  @State loaded: boolean = false;
  @State saving: boolean = false;
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
      this.statusText = '已从本机偏好加载';
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

  private setMode(mode: LlmMode): void {
    const next: AppSettings = this.settings.clone();
    next.llmMode = mode;
    this.settings = next;
  }

  private setLanguage(lang: AppLanguage): void {
    const next: AppSettings = this.settings.clone();
    next.language = lang;
    this.settings = next;
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#0F766E')
      .margin({ top: 18, bottom: 8 })
      .width('100%')
  }

  @Builder
  fieldLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontColor('#64748B')
      .margin({ bottom: 4 })
      .width('100%')
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

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(64)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 4 })

      if (!this.loaded) {
        Text('加载中…')
          .fontColor('#64748B')
          .margin({ top: 40 })
      } else {
        Scroll() {
          Column({ space: 0 }) {
            this.sectionTitle('地图')
            this.fieldLabel('Map API Key（SDK / 通用）')
            TextInput({ text: this.settings.mapApiKey, placeholder: '可选，稍后地图集成使用' })
              .type(InputType.Password)
              .onChange((v: string) => {
                this.settings.mapApiKey = v;
              })
            this.fieldLabel('Map Web Key（HTTP 路线 / POI）')
            TextInput({ text: this.settings.mapWebKey, placeholder: '可选' })
              .type(InputType.Password)
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.settings.mapWebKey = v;
              })

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
              .onChange((v: string) => {
                this.settings.llmBaseUrl = v;
              })
            this.fieldLabel('API Key')
            TextInput({ text: this.settings.llmApiKey, placeholder: 'sk-…（仅存本机）' })
              .type(InputType.Password)
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.settings.llmApiKey = v;
              })
            this.fieldLabel('Model')
            TextInput({ text: this.settings.llmModel, placeholder: 'deepseek-chat' })
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.settings.llmModel = v;
              })
            this.fieldLabel('Proxy Base URL（Mode B）')
            TextInput({ text: this.settings.proxyBaseUrl, placeholder: 'http://127.0.0.1:8787' })
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.settings.proxyBaseUrl = v;
              })

            this.sectionTitle('体验')
            this.fieldLabel('语言')
            Row({ space: 8 }) {
              this.langChip(LANG_ZH_CN, '中文')
              this.langChip(LANG_EN, 'English')
            }
            .width('100%')

            Row() {
              Text('演示 Fixture 优先')
                .fontSize(14)
                .fontColor('#0F172A')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.settings.demoFixtures })
                .selectedColor('#0D9488')
                .onChange((on: boolean) => {
                  this.settings.demoFixtures = on;
                })
            }
            .width('100%')
            .margin({ top: 12 })

            Row() {
              Text('Agent 工具轨迹（调试）')
                .fontSize(14)
                .fontColor('#0F172A')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.settings.verboseAgentTrace })
                .selectedColor('#0D9488')
                .onChange((on: boolean) => {
                  this.settings.verboseAgentTrace = on;
                })
            }
            .width('100%')
            .margin({ top: 8 })

            Text(this.statusText)
              .fontSize(12)
              .fontColor('#64748B')
              .margin({ top: 16 })
              .width('100%')

            Button(this.saving ? '保存中…' : '保存设置')
              .width('100%')
              .height(44)
              .margin({ top: 12, bottom: 32 })
              .backgroundColor('#0D9488')
              .fontColor(Color.White)
              .enabled(!this.saving)
              .onClick(() => {
                this.onSave();
              })
          }
          .padding({ left: 16, right: 16, bottom: 24 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  @Builder
  modeChip(mode: LlmMode, label: string) {
    Button(label, { type: ButtonType.Capsule })
      .fontSize(12)
      .height(32)
      .backgroundColor(this.settings.llmMode === mode ? '#0D9488' : '#E2E8F0')
      .fontColor(this.settings.llmMode === mode ? Color.White : '#334155')
      .onClick(() => {
        this.setMode(mode);
      })
  }

  @Builder
  langChip(lang: AppLanguage, label: string) {
    Button(label, { type: ButtonType.Capsule })
      .fontSize(12)
      .height(32)
      .backgroundColor(this.settings.language === lang ? '#0D9488' : '#E2E8F0')
      .fontColor(this.settings.language === lang ? Color.White : '#334155')
      .onClick(() => {
        this.setLanguage(lang);
      })
  }
}
