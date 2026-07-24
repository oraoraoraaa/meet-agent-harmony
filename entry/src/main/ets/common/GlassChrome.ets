/**
 * Liquid-glass stage + panel helpers (ArkUI port of liquid-glass).
 * Keep stage layers full-bleed only — no orbs, no half-screen color blocks.
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

      // Single full-bleed dark veil (no blue half-panel, no circular orbs)
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
