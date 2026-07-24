import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { AppSettings } from '../common/AppSettings';
import { LocationService } from '../services/location/LocationService';
import { SettingsStore } from '../services/settings/SettingsStore';

@Entry
@Component
struct Index {
  @State settings: AppSettings = new AppSettings();
  @State settingsSummary: string = '设置加载中…';
  @State locationText: string = '尚未请求定位';
  @State locating: boolean = false;

  aboutToAppear(): void {
    this.refreshSettings();
  }

  private hostContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private async refreshSettings(): Promise<void> {
    try {
      this.settings = await SettingsStore.load(this.hostContext());
      const llm: string = this.settings.llmConfigured()
        ? `LLM ${this.settings.modeLabel()} · ${this.settings.llmModel}`
        : `LLM ${this.settings.modeLabel()}（引擎估算可用）`;
      const map: string = this.settings.mapApiKey.trim().length > 0 || this.settings.mapWebKey.trim().length > 0
        ? '地图 Key 已配置'
        : '地图 Key 未配置';
      const fix: string = this.settings.demoFixtures ? 'Fixture 开' : 'Fixture 关';
      this.settingsSummary = `${llm} · ${map} · ${fix}`;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settingsSummary = '设置读取失败 — 将使用默认离线模式';
    }
  }

  private async onLocate(): Promise<void> {
    if (this.locating) {
      return;
    }
    this.locating = true;
    this.locationText = '正在请求定位权限…';
    try {
      const snap = await LocationService.readOnce(this.hostContext());
      this.locationText = snap.message;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.locationText = '定位调用异常';
    } finally {
      this.locating = false;
    }
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开设置页';
    });
  }

  private openPlan(): void {
    router.pushUrl({ url: 'pages/PlanPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开规划页';
    });
  }

  onPageShow(): void {
    this.refreshSettings();
  }

  build() {
    Column() {
      Row() {
        Text('MeetAgent')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
        Button('设置', { type: ButtonType.Capsule })
          .fontSize(13)
          .height(34)
          .backgroundColor('#CCFBF1')
          .fontColor('#0F766E')
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text('会合助手')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('AI 接驾会合规划 · HarmonyOS')
              .fontSize(14)
              .fontColor('#64748B')
            Text('Phase 1 · 确定性规划引擎')
              .fontSize(12)
              .fontColor('#0D9488')
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 8 })

          Column({ space: 10 }) {
            Text('运行状态')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F766E')
              .width('100%')
            Text(this.settingsSummary)
              .fontSize(13)
              .fontColor('#334155')
              .width('100%')
            Divider().color('#E2E8F0')
            Text(this.locationText)
              .fontSize(13)
              .fontColor('#334155')
              .width('100%')
            Button(this.locating ? '定位中…' : '请求一次定位')
              .width('100%')
              .height(40)
              .backgroundColor('#0D9488')
              .fontColor(Color.White)
              .enabled(!this.locating)
              .onClick(() => {
                this.onLocate();
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(Color.White)
          .margin({ left: 16, right: 16 })
          .shadow({
            radius: 16,
            color: '#14000000',
            offsetX: 0,
            offsetY: 6
          })

          Column({ space: 8 }) {
            Text('会合规划')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F766E')
              .width('100%')
            Text('双点输入 · 步行/骑行/公交/原地等待 · 估算路线示意（无需 LLM）')
              .fontSize(13)
              .fontColor('#475569')
              .width('100%')
            Button('开始规划')
              .width('100%')
              .height(44)
              .margin({ top: 4 })
              .backgroundColor('#0D9488')
              .fontColor(Color.White)
              .onClick(() => {
                this.openPlan();
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(Color.White)
          .margin({ left: 16, right: 16 })

          Column({ space: 8 }) {
            Text('下一步（Phase 2）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F766E')
              .width('100%')
            Text('· 自然语言对话与工具循环\\n· 用户 Key / 代理 / 离线降级\\n· 决策过程轨迹')
              .fontSize(13)
              .fontColor('#475569')
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(Color.White)
          .margin({ left: 16, right: 16, bottom: 24 })

          Text('密钥仅存本机偏好；无 Key 时仍可走离线估算。')
            .fontSize(11)
            .fontColor('#94A3B8')
            .padding({ left: 20, right: 20, bottom: 28 })
            .width('100%')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F5F9')
  }
}
