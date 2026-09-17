import { AppTheme } from './AppTheme';

@Component
export struct StageBackground {
  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.bg0)
  }
}
