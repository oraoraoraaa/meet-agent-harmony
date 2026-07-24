import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { StageBackground } from '../common/GlassChrome';
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
        : `LLM ${this.settings.modeLabel()} · 引擎估算可用`;
      const map: string = this.settings.mapApiKey.trim().length > 0 || this.settings.mapWebKey.trim().length > 0
        ? '地图 Key 已配置'
        : '地图示意模式';
      this.settingsSummary = `${llm} · ${map}`;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.settingsSummary = '设置读取失败 — 默认离线模式';
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
    Stack({ alignContent: Alignment.Bottom }) {
      StageBackground()

      Row() {
        Column({ space: 2 }) {
          Text('会合助手')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
          Text('MeetAgent · liquid glass')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('设置', { type: ButtonType.Capsule })
          .height(36)
          .fontSize(13)
          .backgroundColor(AppTheme.glassBgLight)
          .fontColor(AppTheme.ink)
          .border({ width: 1, color: AppTheme.glassBorder })
          .backdropBlur(AppTheme.blurSoft)
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 18, bottom: 8 })
      .position({ x: 0, y: 0 })

      Column({ space: 6 }) {
        Text('西安示意地图')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
        Text('实时路网 / POI 搜索 · 即将接入')
          .fontSize(13)
          .fontColor(AppTheme.inkMuted)
        Row({ space: 8 }) {
          Text('📍 司机')
            .fontSize(11)
            .fontColor(AppTheme.ink)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(AppTheme.radiusPill)
            .backgroundColor(AppTheme.glassBgLight)
            .border({ width: 1, color: AppTheme.lineStrong })
            .backdropBlur(10)
          Text('📍 乘客')
            .fontSize(11)
            .fontColor(AppTheme.ink)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(AppTheme.radiusPill)
            .backgroundColor(AppTheme.accentSoft)
            .border({ width: 1, color: AppTheme.lineFocus })
            .backdropBlur(10)
        }
        .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22 })
      .position({ x: 0, y: 96 })

      Column({ space: 12 }) {
        Text('接驾会合规划')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
          .width('100%')
        Text('乘客在哪？司机从哪出发？一次锁定会合方案。')
          .fontSize(13)
          .fontColor(AppTheme.inkMuted)
          .width('100%')

        Column({ space: 6 }) {
          Text('乘客位置')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .width('100%')
          Row() {
            Text('🔍  搜索地点或地址 · 即将接入')
              .fontSize(14)
              .fontColor(AppTheme.inkFaint)
              .layoutWeight(1)
          }
          .width('100%')
          .height(46)
          .padding({ left: 14, right: 14 })
          .borderRadius(14)
          .backgroundColor(AppTheme.fieldBg)
          .border({ width: 1, color: AppTheme.lineStrong })
        }
        .width('100%')

        Column({ space: 6 }) {
          Text('司机出发地（可选）')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .width('100%')
          Row() {
            Text(this.locationText)
              .fontSize(13)
              .fontColor(AppTheme.inkMuted)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(46)
          .padding({ left: 14, right: 14 })
          .borderRadius(14)
          .backgroundColor(AppTheme.fieldBg)
          .border({ width: 1, color: AppTheme.lineStrong })
        }
        .width('100%')

        Row({ space: 10 }) {
          Button(this.locating ? '定位中…' : '用当前定位', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(42)
            .fontSize(13)
            .backgroundColor(AppTheme.accentSoft)
            .fontColor(AppTheme.link)
            .border({ width: 1, color: AppTheme.lineFocus })
            .enabled(!this.locating)
            .onClick(() => {
              this.onLocate();
            })
          Button('设置', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(42)
            .fontSize(13)
            .backgroundColor(AppTheme.glassBgLight)
            .fontColor(AppTheme.ink)
            .border({ width: 1, color: AppTheme.glassBorder })
            .onClick(() => {
              this.openSettings();
            })
        }
        .width('100%')

        Text(this.settingsSummary)
          .fontSize(11)
          .fontColor(AppTheme.inkSoft)
          .width('100%')

        Button('开始路线优化', { type: ButtonType.Capsule })
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppTheme.accent)
          .fontColor(Color.White)
          .border({ width: 1, color: '#59FFFFFF' })
          .shadow({
            radius: 22,
            color: '#590A84FF',
            offsetX: 0,
            offsetY: 10
          })
          .onClick(() => {
            this.openPlan();
          })

        Text('无 Key 时使用离线估算 · 密钥仅存本机')
          .fontSize(11)
          .fontColor(AppTheme.inkSoft)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 30 })
      .borderRadius({ topLeft: AppTheme.radiusLg, topRight: AppTheme.radiusLg })
      .backgroundColor(AppTheme.glassBg)
      .backdropBlur(AppTheme.blurStrong)
      .border({ width: { top: 1 }, color: AppTheme.glassBorder })
      .shadow({
        radius: 36,
        color: '#80000000',
        offsetX: 0,
        offsetY: -8
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
  }
}
