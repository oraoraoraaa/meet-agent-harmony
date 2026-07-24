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
import { AppTheme } from '../common/AppTheme';
import { StageBackground } from '../common/GlassChrome';
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

          Text('设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank().width(40)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 10, bottom: 4 })

        if (!this.loaded) {
          Text('加载中…')
            .fontColor(AppTheme.inkMuted)
            .margin({ top: 40 })
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Column() {
                this.sectionTitle('语言')
                Row({ space: 8 }) {
                  this.langChip(LANG_ZH_CN, '简体中文')
                  this.langChip(LANG_EN, 'English')
                }
                .width('100%')
                Text('日语界面 · 即将接入')
                  .fontSize(11)
                  .fontColor(AppTheme.inkSoft)
                  .margin({ top: 8 })
                  .width('100%')

                this.sectionTitle('默认地图应用')
                Column({ space: 8 }) {
                  this.placeholderRow('高德地图 (AMap)', false)
                  this.placeholderRow('Apple 地图', false)
                  this.placeholderRow('百度地图', false)
                  this.placeholderRow('浏览器', false)
                }
                .width('100%')
                Text('打开地图跳转 · Phase 3 接入')
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
                color: '#59000000',
                offsetX: 0,
                offsetY: 12
              })

              Column() {
                this.sectionTitle('地图 Key')
                this.fieldLabel('Map API Key（SDK / 通用）')
                TextInput({ text: this.settings.mapApiKey, placeholder: '可选，稍后地图集成使用' })
                  .type(InputType.Password)
                  .height(46)
                  .borderRadius(14)
                  .backgroundColor(AppTheme.fieldBg)
                  .fontColor(AppTheme.ink)
                  .placeholderColor(AppTheme.inkFaint)
                  .border({ width: 1, color: AppTheme.lineStrong })
                  .onChange((v: string) => {
                    this.settings.mapApiKey = v;
                  })
                this.fieldLabel('Map Web Key（HTTP 路线 / POI）')
                TextInput({ text: this.settings.mapWebKey, placeholder: '可选' })
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

                this.sectionTitle('体验')
                Row() {
                  Text('演示 Fixture 优先')
                    .fontSize(14)
                    .fontColor(AppTheme.ink)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.settings.demoFixtures })
                    .selectedColor(AppTheme.accent)
                    .onChange((on: boolean) => {
                      this.settings.demoFixtures = on;
                    })
                }
                .width('100%')
                .margin({ top: 8 })

                Row() {
                  Text('Agent 工具轨迹（调试）')
                    .fontSize(14)
                    .fontColor(AppTheme.ink)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.settings.verboseAgentTrace })
                    .selectedColor(AppTheme.accent)
                    .onChange((on: boolean) => {
                      this.settings.verboseAgentTrace = on;
                    })
                }
                .width('100%')
                .margin({ top: 8 })

                Text(this.statusText)
                  .fontSize(12)
                  .fontColor(AppTheme.inkMuted)
                  .margin({ top: 16 })
                  .width('100%')

                Button(this.saving ? '保存中…' : '保存设置', { type: ButtonType.Capsule })
                  .width('100%')
                  .height(48)
                  .margin({ top: 12, bottom: 8 })
                  .backgroundColor(AppTheme.accent)
                  .fontColor(Color.White)
                  .border({ width: 1, color: '#59FFFFFF' })
                  .shadow({
                    radius: 20,
                    color: '#590A84FF',
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
                color: '#59000000',
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
  langChip(lang: AppLanguage, label: string) {
    Button(label, { type: ButtonType.Capsule })
      .fontSize(12)
      .height(32)
      .backgroundColor(this.settings.language === lang ? AppTheme.accent : AppTheme.glassBgLight)
      .fontColor(this.settings.language === lang ? Color.White : AppTheme.ink)
      .border({ width: 1, color: this.settings.language === lang ? AppTheme.lineFocus : AppTheme.glassBorder })
      .onClick(() => {
        this.setLanguage(lang);
      })
  }

  @Builder
  placeholderRow(label: string, selected: boolean) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppTheme.ink)
        .layoutWeight(1)
      Text(selected ? '✓' : '·')
        .fontSize(14)
        .fontColor(selected ? AppTheme.link : AppTheme.inkSoft)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(14)
    .backgroundColor(selected ? AppTheme.accentSoft : AppTheme.fieldBg)
    .border({ width: 1, color: selected ? AppTheme.lineFocus : AppTheme.line })
  }
}
