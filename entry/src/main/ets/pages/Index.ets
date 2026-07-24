import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
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
      // map stage backdrop
      Column() {
        Column() {
          Text('MeetAgent · 会合助手')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 56, left: 20 })
            .width('100%')
          Text('西安示意地图')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textOnLight)
            .margin({ top: 8, left: 20 })
          Text('实时路网 / POI 搜索 · 即将接入')
            .fontSize(12)
            .fontColor(AppTheme.textOnLightSecondary)
            .margin({ top: 4, left: 20, bottom: 12 })

          // faux map grid
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .linearGradient({
                angle: 135,
                colors: [['#DCE8F2', 0], ['#E8F5E9', 0.55], ['#E2E8F0', 1]]
              })
            // road-ish lines
            ForEach([0.18, 0.36, 0.54, 0.72, 0.88], (t: number, idx: number) => {
              Divider()
                .color(idx % 2 === 0 ? '#94A3B8' : '#86EFAC')
                .strokeWidth(idx % 2 === 0 ? 2 : 1.5)
                .opacity(0.45)
                .width('120%')
                .rotate({ angle: idx % 2 === 0 ? -12 : 18 })
                .position({ x: -20, y: `${t * 100}%` })
            }, (t: number, idx: number) => `road-${idx}`)
            // pins
            Column() {
              Text('📍 司机')
                .fontSize(11)
                .fontColor(AppTheme.tealDeep)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#CCFBF1')
                .borderRadius(999)
            }
            .position({ x: '18%', y: '28%' })
            Column() {
              Text('📍 乘客')
                .fontSize(11)
                .fontColor('#B45309')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#FEF3C7')
                .borderRadius(999)
            }
            .position({ x: '58%', y: '52%' })
            Text('高德风格示意 · 非真实地图')
              .fontSize(10)
              .fontColor(AppTheme.textMuted)
              .position({ x: 12, y: '90%' })
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ left: 12, right: 12, bottom: 12 })
          .borderRadius(18)
          .clip(true)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.bg)

      // top chrome
      Row() {
        Text('会合助手')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
        Button('设置', { type: ButtonType.Capsule })
          .fontSize(13)
          .height(34)
          .backgroundColor('#1F2937')
          .fontColor(AppTheme.text)
          .border({ width: 1, color: AppTheme.border })
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 14, bottom: 8 })
      .position({ x: 0, y: 0 })

      // bottom glass sheet
      Column({ space: 12 }) {
        Text('接驾会合规划')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textOnLight)
          .width('100%')
        Text('乘客在哪？司机从哪出发？一次锁定会合方案。')
          .fontSize(13)
          .fontColor(AppTheme.textOnLightSecondary)
          .width('100%')

        Column({ space: 6 }) {
          Text('乘客位置')
            .fontSize(12)
            .fontColor(AppTheme.textMuted)
            .width('100%')
          Row() {
            Text('🔍  搜索地点或地址 · 即将接入')
              .fontSize(14)
              .fontColor(AppTheme.textMuted)
              .layoutWeight(1)
          }
          .width('100%')
          .height(44)
          .padding({ left: 12, right: 12 })
          .borderRadius(12)
          .backgroundColor(Color.White)
          .border({ width: 1, color: AppTheme.hairline })
        }
        .width('100%')

        Column({ space: 6 }) {
          Text('司机出发地（可选）')
            .fontSize(12)
            .fontColor(AppTheme.textMuted)
            .width('100%')
          Row() {
            Text(this.locationText.length > 0 ? this.locationText : '搜索出发地点 · 即将接入')
              .fontSize(13)
              .fontColor(AppTheme.textOnLightSecondary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(44)
          .padding({ left: 12, right: 12 })
          .borderRadius(12)
          .backgroundColor(Color.White)
          .border({ width: 1, color: AppTheme.hairline })
        }
        .width('100%')

        Row({ space: 8 }) {
          Button(this.locating ? '定位中…' : '用当前定位', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#CCFBF1')
            .fontColor(AppTheme.tealDeep)
            .enabled(!this.locating)
            .onClick(() => {
              this.onLocate();
            })
          Button('设置', { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#E2E8F0')
            .fontColor(AppTheme.textOnLight)
            .onClick(() => {
              this.openSettings();
            })
        }
        .width('100%')

        Text(this.settingsSummary)
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
          .width('100%')

        Button('开始路线优化', { type: ButtonType.Capsule })
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppTheme.primary)
          .fontColor(AppTheme.textOnPrimary)
          .onClick(() => {
            this.openPlan();
          })

        Text('无 Key 时使用离线估算 · 密钥仅存本机')
          .fontSize(11)
          .fontColor(AppTheme.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 28 })
      .borderRadius({ topLeft: 24, topRight: 24 })
      .backgroundColor(AppTheme.glass)
      .shadow({
        radius: 24,
        color: '#66000000',
        offsetX: 0,
        offsetY: -4
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg)
  }
}
