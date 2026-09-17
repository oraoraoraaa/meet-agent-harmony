import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
/** App window background — must match AppTheme.bg0 / start_window_background. */
const WINDOW_BG: string = '#F2F2F7';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.paintImmersiveWindow(windowStage);
    });
  }

  /**
   * Match the light launch surface and keep dark system-bar text readable.
   */
  private paintImmersiveWindow(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win: window.Window) => {
      try {
        win.setWindowLayoutFullScreen(true);
      } catch (e) {
        hilog.warn(DOMAIN, 'testTag', 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(e));
      }
      try {
        win.setWindowBackgroundColor(WINDOW_BG);
      } catch (e) {
        hilog.warn(DOMAIN, 'testTag', 'setWindowBackgroundColor failed: %{public}s', JSON.stringify(e));
      }
      try {
        const bar: window.SystemBarProperties = {
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          // Dark icons on the light surface
          statusBarContentColor: '#1C1C1E',
          navigationBarContentColor: '#1C1C1E'
        };
        win.setWindowSystemBarProperties(bar);
      } catch (e) {
        hilog.warn(DOMAIN, 'testTag', 'setWindowSystemBarProperties failed: %{public}s', JSON.stringify(e));
      }
    }).catch((e: Error) => {
      hilog.error(DOMAIN, 'testTag', 'getMainWindow failed: %{public}s', JSON.stringify(e));
    });
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
  }

  onBackground(): void {
  }
}
