import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from './AppTheme';

/** Reuse existing routes so tab changes never accumulate duplicate pages. */
@Component
export struct BottomNavigation {
  @Prop active: string = 'map';
  @Prop allowActiveNavigation: boolean = false;

  private open(id: string, page: string): void {
    if (id === this.active && !this.allowActiveNavigation) return;
    router.pushUrl({ url: page }, router.RouterMode.Single).catch(() => {
      promptAction.showToast({ message: '暂时无法打开，请重试' });
    });
  }

  @Builder
  item(id: string, label: string, symbol: Resource, selectedSymbol: Resource, page: string) {
    Column({ space: 4 }) {
      Image(this.active === id ? selectedSymbol : symbol).width(23).height(23)
      Text(label).fontSize(11).fontWeight(FontWeight.Medium)
        .fontColor(this.active === id ? AppTheme.accent : AppTheme.inkSoft)
    }
    .layoutWeight(1).height(54).justifyContent(FlexAlign.Center)
    .borderRadius(16)
    .backgroundColor(this.active === id ? AppTheme.accentSoft : Color.Transparent)
    .accessibilityText(label)
    .onClick(() => { this.open(id, page); })
  }

  build() {
    Row({ space: 6 }) {
      this.item('map', '地图', $r('app.media.tab_map'), $r('app.media.tab_map_active'), 'pages/Index')
      this.item('chat', '助手', $r('app.media.tab_chat'), $r('app.media.tab_chat_active'), 'pages/ChatPage')
      this.item('trip', '行程', $r('app.media.tab_trip'), $r('app.media.tab_trip_active'), 'pages/LockedSessionPage')
      this.item('settings', '设置', $r('app.media.tab_settings'), $r('app.media.tab_settings_active'), 'pages/SettingsPage')
    }
    .width('100%').padding({ left: 18, right: 18, top: 8, bottom: 22 })
    .backgroundColor(AppTheme.bg1)
    .border({ width: { top: 0.5 }, color: AppTheme.line })
  }
}
