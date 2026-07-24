@Entry
@Component
struct Index {
  @State message: string = 'MeetAgent';
  @State subtitle: string = '会合助手 · HarmonyOS';

  build() {
    Column({ space: 12 }) {
      Text(this.message)
        .id('AppTitle')
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
      Text(this.subtitle)
        .fontSize(14)
        .fontColor('#666666')
      Text('Phase 0 shell — open this repo root in DevEco Studio')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 24 })
        .onClick(() => {
          this.message = 'MeetAgent ready';
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
