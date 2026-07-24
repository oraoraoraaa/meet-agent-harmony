import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
/** App stage black — must match AppTheme.bg0 / start_window_background. */
const WINDOW_BG: string = '#07080C';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.paintImmersiveWindow(windowStage);
    });
  }

  /**
   * Edge-to-edge dark window so status/nav bars do not flash light gray
   * (legacy start_window_background #F1F5F9) above/below content.
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
          // Light icons on dark stage
          statusBarContentColor: '#F5F5F7',
          navigationBarContentColor: '#F5F5F7'
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
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
