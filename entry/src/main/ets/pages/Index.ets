import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { AppLayout } from '../common/AppLayout';
import { StageBackground } from '../common/GlassChrome';
import { AppSettings } from '../common/AppSettings';
import { LocationService } from '../services/location/LocationService';
import { SettingsStore } from '../services/settings/SettingsStore';

/**
 * Home: map stage on top (reserved for future live map) + fixed-height
 * scrollable bottom sheet. Role mode (driver/passenger) lives as a compact
 * upper-right control — never on the map center.
 */
@Entry
@Component
struct Index {
  @State settings: AppSettings = new AppSettings();
  @State settingsSummary: string = '设置加载中…';
  @State locationText: string = '尚未请求定位';
  @State locating: boolean = false;
  /**
   * Planning role (single device). Not dual-phone sync.
   * 'driver' | 'passenger'
   */
  @State roleMode: string = 'driver';
  /** Expanded mode picker (collapsed chip → menu). */
  @State modeMenuOpen: boolean = false;
  /** Bottom sheet height vp — fixed so map stage keeps visible space. */
  private readonly sheetHeightVp: number = 340;

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
    this.locationText = '正在请求定位…';
    try {
      const snap = await LocationService.readOnce(this.hostContext());
      this.locationText = snap.message;
    } catch (e) {
      const _ignored: Object = e as Object;
      this.locationText = '定位调用异常 — 可改用手动选点';
    } finally {
      this.locating = false;
    }
  }

  private openSettings(): void {
    this.modeMenuOpen = false;
    router.pushUrl({ url: 'pages/SettingsPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开设置页';
    });
  }

  private openPlan(): void {
    this.modeMenuOpen = false;
    router.pushUrl({ url: 'pages/PlanPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开规划页';
    });
  }

  private openChat(): void {
    this.modeMenuOpen = false;
    router.pushUrl({ url: 'pages/ChatPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开助手页';
    });
  }

  private openLocked(): void {
    this.modeMenuOpen = false;
    router.pushUrl({ url: 'pages/LockedSessionPage' }).then(() => {
    }).catch(() => {
      this.settingsSummary = '无法打开锁定方案页';
    });
  }

  private modeChipLabel(): string {
    return this.roleMode === 'passenger' ? '乘客模式' : '司机模式';
  }

  private toggleModeMenu(): void {
    this.modeMenuOpen = !this.modeMenuOpen;
  }

  private selectRoleMode(mode: string): void {
    if (mode === 'driver' || mode === 'passenger') {
      this.roleMode = mode;
    }
    this.modeMenuOpen = false;
  }

  onPageShow(): void {
    this.refreshSettings();
  }

  build() {
    Stack() {
      // Full-bleed stage (draws under status / nav bars)
      StageBackground()
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Column() {
        // —— Top chrome: title | mode chip (UR) | settings ——
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('会合助手')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
            Text('MeetAgent · liquid glass')
              .fontSize(11)
              .fontColor(AppTheme.inkSoft)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // Collapsed mode pill — upper right, not on map
          Button(this.modeChipLabel(), { type: ButtonType.Capsule })
            .height(34)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#5AC8C8')
            .border({ width: 1, color: '#66FFFFFF' })
            .shadow({
              radius: 12,
              color: '#4000A8A8',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              this.toggleModeMenu();
            })

          Button('设置', { type: ButtonType.Capsule })
            .height(34)
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
        .padding({ left: 18, right: 16, top: 8, bottom: 6 })
        // Keep title below status bar while stage fills behind it
        .margin({ top: AppLayout.statusBarInsetVp })

        // —— Map stage (clean — no mode switch overlay) ——
        Column({ space: 8 }) {
          Column({ space: 4 }) {
            Text('西安示意地图')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
              .width('100%')
              .textAlign(TextAlign.Start)
            Text('实时路网 / POI 搜索 · 即将接入')
              .fontSize(12)
              .fontColor(AppTheme.inkMuted)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 18, right: 18 })

          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%')
              .height('100%')
              .borderRadius(16)
              .backgroundColor(AppTheme.mapPanel)
              .opacity(0.9)

            // Schematic only — markers reflect current role, no controls here
            Column({ space: 10 }) {
              Text('地图舞台')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.ink)
              Text('预留区域 · 后续接入路网')
                .fontSize(11)
                .fontColor(AppTheme.inkSoft)

              Row({ space: 28 }) {
                Column({ space: 4 }) {
                  Circle({
                    width: this.roleMode === 'driver' ? 14 : 10,
                    height: this.roleMode === 'driver' ? 14 : 10
                  })
                    .fill(this.roleMode === 'driver' ? AppTheme.accent : AppTheme.link)
                  Text('司机')
                    .fontSize(10)
                    .fontColor(AppTheme.inkMuted)
                }
                .alignItems(HorizontalAlign.Center)

                Column({ space: 4 }) {
                  Circle({
                    width: this.roleMode === 'passenger' ? 14 : 10,
                    height: this.roleMode === 'passenger' ? 14 : 10
                  })
                    .fill(this.roleMode === 'passenger' ? '#EF4444' : AppTheme.warn)
                  Text('乘客')
                    .fontSize(10)
                    .fontColor(AppTheme.inkMuted)
                }
                .alignItems(HorizontalAlign.Center)
              }
              .margin({ top: 6 })

              Text(
                this.roleMode === 'driver'
                  ? '当前：司机视角规划'
                  : '当前：乘客视角规划'
              )
                .fontSize(10)
                .fontColor(AppTheme.inkSoft)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Center)
            .padding(16)
          }
          .width('100%')
          .layoutWeight(1)
          .constraintSize({ minHeight: 140 })
          .margin({ left: 18, right: 18, bottom: 8 })
          .clip(true)
          .borderRadius(16)
          .border({ width: 1, color: AppTheme.glassBorder })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // —— Fixed-height scrollable bottom sheet ——
        Column() {
          Row() {
            Column()
              .width(40)
              .height(4)
              .borderRadius(2)
              .backgroundColor(AppTheme.glassBorder)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 4 })

          Scroll() {
            Column({ space: 12 }) {
              Text('接驾会合规划')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
                .width('100%')
              Text(
                this.roleMode === 'driver'
                  ? '你是司机：选乘客位置，一次锁定会合方案。'
                  : '你是乘客：选上车点，一次锁定会合方案。'
              )
                .fontSize(13)
                .fontColor(AppTheme.inkMuted)
                .width('100%')

              Column({ space: 6 }) {
                Text(this.roleMode === 'driver' ? '乘客位置' : '你的位置（乘客）')
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
                Text(this.roleMode === 'driver' ? '司机出发地（可选）' : '司机出发地（可选）')
                  .fontSize(12)
                  .fontColor(AppTheme.inkSoft)
                  .width('100%')
                Row() {
                  Text(this.locationText)
                    .fontSize(12)
                    .fontColor(AppTheme.inkMuted)
                    .layoutWeight(1)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .constraintSize({ minHeight: 46 })
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
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

              Button('智能助手规划', { type: ButtonType.Capsule })
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
                  this.openChat();
                })

              Button('表单规划（离线引擎）', { type: ButtonType.Capsule })
                .width('100%')
                .height(44)
                .fontSize(14)
                .backgroundColor(AppTheme.glassBgLight)
                .fontColor(AppTheme.ink)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.openPlan();
                })

              Button('已锁定方案', { type: ButtonType.Capsule })
                .width('100%')
                .height(42)
                .fontSize(14)
                .backgroundColor(AppTheme.glassBg)
                .fontColor(AppTheme.inkMuted)
                .border({ width: 1, color: AppTheme.glassBorder })
                .onClick(() => {
                  this.openLocked();
                })

              Text('无 Key 时使用离线估算 · 确认后锁定会合点 · 密钥仅存本机')
                .fontSize(11)
                .fontColor(AppTheme.inkSoft)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 8 })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 6, bottom: 20 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.Top)
        }
        .width('100%')
        .height(this.sheetHeightVp)
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
        .clip(true)
      }
      .width('100%')
      .height('100%')
      // Content uses expandSafeArea + header margin; no hard top pad that leaves light strips
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // —— Mode selection overlay (top-right expand menu; not on map) ——
      if (this.modeMenuOpen) {
        Stack({ alignContent: Alignment.TopEnd }) {
          // Full-screen dim + dismiss
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .onClick(() => {
              this.modeMenuOpen = false;
            })

          Column({ space: 10 }) {
            Text('选择模式')
              .fontSize(13)
              .fontColor(AppTheme.inkSoft)
              .width('100%')

            Row() {
              Text('我是司机')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .layoutWeight(1)
              if (this.roleMode === 'driver') {
                Text('✓')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 14 })
            .borderRadius(14)
            .backgroundColor(this.roleMode === 'driver' ? '#3A4A5C' : '#2A3544')
            .border({
              width: 1,
              color: this.roleMode === 'driver' ? AppTheme.lineFocus : AppTheme.line
            })
            .onClick(() => {
              this.selectRoleMode('driver');
            })

            Row() {
              Text('我是乘客')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .layoutWeight(1)
              if (this.roleMode === 'passenger') {
                Text('✓')
                  .fontSize(16)
                  .fontColor(Color.White)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 14 })
            .borderRadius(14)
            .backgroundColor(this.roleMode === 'passenger' ? '#3A4A5C' : '#2A3544')
            .border({
              width: 1,
              color: this.roleMode === 'passenger' ? AppTheme.lineFocus : AppTheme.line
            })
            .onClick(() => {
              this.selectRoleMode('passenger');
            })

            Text('单机规划视角 · 非双机同步')
              .fontSize(10)
              .fontColor(AppTheme.inkSoft)
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          .width(260)
          .padding(16)
          .margin({ top: AppLayout.headerTop() + 48, right: 16 })
          .borderRadius(18)
          .backgroundColor('#E0182430')
          .backdropBlur(AppTheme.blurPanel)
          .border({ width: 1, color: AppTheme.glassBorder })
          .shadow({
            radius: 28,
            color: '#80000000',
            offsetX: 0,
            offsetY: 12
          })
        }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.bg0)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
