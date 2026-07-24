/**
 * Liquid-glass stage background (ArkUI port of liquid-glass stage veil).
 * Full-bleed photo + dark gradient only — no orbs / half-screen washes.
 */

@Component
export struct StageBackground {
  build() {
    Stack() {
      Image($r('app.media.stage_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['#CC05060A', 0.0],
            ['#B80A0C12', 0.5],
            ['#F005060A', 1.0]
          ]
        })
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
