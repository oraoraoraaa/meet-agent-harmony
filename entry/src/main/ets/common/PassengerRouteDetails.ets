import { AppTheme } from './AppTheme';
import { PassengerLeg } from '../domain/Models';

/** A timeline of the selected provider itinerary; missing details stay explicitly unavailable. */
@Component
export struct PassengerRouteDetails {
  @Prop legs: PassengerLeg[] = [];
  @Prop fromName: string = '';
  @Prop toName: string = '';
  @Prop etaMin: number = 0;
  @Prop source: string = '';
  onClose: () => void = () => {};

  private title(leg: PassengerLeg): string {
    if (leg.mode === 'walking') return '步行';
    if (leg.lineName.length > 0) return leg.lineName;
    if (leg.mode === 'subway') return '乘坐地铁';
    if (leg.mode === 'railway') return '乘坐列车';
    if (leg.mode === 'taxi') return '乘坐出租车';
    return '乘坐公共汽车';
  }

  private metrics(leg: PassengerLeg): string {
    const parts: string[] = [];
    if (leg.durationMin >= 0) parts.push(`约 ${Math.ceil(leg.durationMin)} 分钟`);
    if (leg.distanceM >= 0) parts.push(leg.distanceM >= 1000
      ? `${(leg.distanceM / 1000).toFixed(1)} 公里` : `${Math.round(leg.distanceM)} 米`);
    if (leg.stopCount >= 0) parts.push(`途经 ${leg.stopCount} 站`);
    return parts.join(' · ');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#44000000')
        .onClick(() => { this.onClose(); })
      Column({ space: 12 }) {
        Row() {
          Column({ space: 3 }) {
            Text('乘客路线').fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
            Text(`公共交通 · 约 ${this.etaMin.toFixed(0)} 分钟 · ${this.source}`)
              .fontSize(13).fontColor(AppTheme.inkSoft)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('关闭').height(36).fontSize(14).fontColor(AppTheme.accent)
            .backgroundColor(AppTheme.accentSoft).onClick(() => { this.onClose(); })
        }.width('100%')
        Scroll() {
          Column({ space: 18 }) {
            Text(`出发 · ${this.fromName}`).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.ink).width('100%')
            if (this.legs.length === 0) {
              Text('暂未获取到分段路线。当前仅有行程估算，请在地图应用中确认具体线路。')
                .fontSize(15).fontColor(AppTheme.inkSoft).width('100%')
            }
            ForEach(this.legs, (leg: PassengerLeg) => {
              Row({ space: 14 }) {
                Image(leg.mode === 'walking' ? $r('app.media.mode_walk') : $r('app.media.mode_transit'))
                  .width(28).height(28).margin({ top: 3 })
                Column({ space: 7 }) {
                  Text(this.title(leg)).fontSize(18).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
                  if (leg.fromName.length > 0) {
                    Text(`上车 · ${leg.fromName}`).fontSize(14).fontColor(AppTheme.ink)
                  }
                  if (leg.toName.length > 0) {
                    Text(`下车 · ${leg.toName}`).fontSize(14).fontColor(AppTheme.ink)
                  }
                  if (this.metrics(leg).length > 0) {
                    Text(this.metrics(leg)).fontSize(13).fontColor(AppTheme.accent)
                  }
                  if (leg.entrance.length > 0) {
                    Text(`进站 · ${leg.entrance}`).fontSize(13).fontColor(AppTheme.inkSoft)
                  }
                  if (leg.exit.length > 0) {
                    Text(`出站 · ${leg.exit}`).fontSize(13).fontColor(AppTheme.inkSoft)
                  }
                  if (leg.serviceHours.length > 0) {
                    Text(`运营时间 · ${leg.serviceHours}`).fontSize(13).fontColor(AppTheme.inkSoft)
                  }
                  ForEach(leg.instructions, (instruction: string) => {
                    Text(instruction).fontSize(13).fontColor(AppTheme.inkSoft)
                  })
                  Divider().color(AppTheme.line).margin({ top: 8 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
            })
            Text(`到达 · ${this.toName}`).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.ink).width('100%')
          }.width('100%').padding({ bottom: 20 })
        }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
      }.width('100%').height('80%').padding({ left: 24, right: 24, top: 24, bottom: 28 })
        .backgroundColor(AppTheme.bg1).borderRadius({ topLeft: 28, topRight: 28 })
    }.width('100%').height('100%')
  }
}
