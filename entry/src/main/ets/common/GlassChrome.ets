/**
 * Liquid-glass stage + panel helpers (ArkUI port of liquid-glass).
 */

import { AppTheme } from './AppTheme';

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
          angle: 165,
          colors: [
            ['#C705060A', 0.0],
            ['#B80C0E14', 0.45],
            ['#E005060A', 1.0]
          ]
        })

      // ambient blue glow
      Column()
        .width('80%')
        .height('40%')
        .borderRadius(999)
        .backgroundColor('#330A84FF')
        .blur(48)
        .position({ x: '-10%', y: '-6%' })

      // ambient violet glow
      Column()
        .width('70%')
        .height('36%')
        .borderRadius(999)
        .backgroundColor('#285E5CE6')
        .blur(52)
        .position({ x: '45%', y: '6%' })
    }
    .width('100%')
    .height('100%')
  }
}

/** Standard frosted panel style chain for Column hosts. */
export function styleGlassPanel(
  node: ColumnAttribute,
  radius: number = AppTheme.radiusLg,
  blur: number = AppTheme.blurPanel,
  fill: string = AppTheme.glassBg
): ColumnAttribute {
  return node
    .borderRadius(radius)
    .backgroundColor(fill)
    .backdropBlur(blur)
    .border({ width: 1, color: AppTheme.glassBorder })
    .shadow({
      radius: 30,
      color: '#66000000',
      offsetX: 0,
      offsetY: 14
    })
    .clip(true);
}

export function styleGlassPrimaryButton(node: ButtonAttribute): ButtonAttribute {
  return node
    .borderRadius(AppTheme.radiusPill)
    .backgroundColor(AppTheme.accent)
    .fontColor(Color.White)
    .fontWeight(FontWeight.Medium)
    .border({ width: 1, color: '#59FFFFFF' })
    .shadow({
      radius: 20,
      color: '#590A84FF',
      offsetX: 0,
      offsetY: 8
    });
}

export function styleGlassSecondaryButton(node: ButtonAttribute): ButtonAttribute {
  return node
    .borderRadius(AppTheme.radiusPill)
    .backgroundColor(AppTheme.glassBgLight)
    .fontColor(AppTheme.ink)
    .border({ width: 1, color: AppTheme.glassBorder })
    .backdropBlur(AppTheme.blurSoft);
}

export function styleGlassField(node: TextInputAttribute): TextInputAttribute {
  return node
    .height(46)
    .borderRadius(14)
    .backgroundColor(AppTheme.fieldBg)
    .fontColor(AppTheme.ink)
    .placeholderColor(AppTheme.inkFaint)
    .caretColor(AppTheme.accent)
    .border({ width: 1, color: AppTheme.lineStrong })
    .padding({ left: 12, right: 12 });
}
