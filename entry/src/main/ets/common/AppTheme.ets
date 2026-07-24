/**
 * Liquid-glass tokens ported from liquid-glass (Apple TV stage + frosted controls).
 * Harmony Color strings: prefer #AARRGGBB when alpha is needed.
 */

export class AppTheme {
  // Stage
  static readonly bg0: string = '#07080C';
  static readonly bg1: string = '#12141C';

  // Glass fills — denser so form text stays readable over stage photo
  static readonly glassBg: string = '#B3121620'; // ~70% dark
  static readonly glassBgStrong: string = '#C2181C28';
  static readonly glassBgLight: string = '#33FFFFFF';
  static readonly glassBgLighter: string = '#24FFFFFF';
  static readonly glassBorder: string = '#3DFFFFFF';
  static readonly glassHighlight: string = '#4DFFFFFF';

  // Ink on glass — brighter for contrast
  static readonly ink: string = '#F5F5F7';
  static readonly inkMuted: string = '#D9FFFFFF'; // ~85%
  static readonly inkSoft: string = '#B3FFFFFF'; // ~70%
  static readonly inkFaint: string = '#8CFFFFFF'; // ~55%

  // Lines
  static readonly line: string = '#33FFFFFF';
  static readonly lineStrong: string = '#4DFFFFFF';
  static readonly lineFocus: string = '#CC0A84FF';

  // Accent
  static readonly accent: string = '#0A84FF';
  static readonly accentStrong: string = '#409CFF';
  static readonly accentSoft: string = '#4D0A84FF';
  static readonly accentGlow: string = '#590A84FF';
  static readonly link: string = '#64D2FF';
  static readonly success: string = '#30D158';
  static readonly warn: string = '#FF9F0A';
  static readonly danger: string = '#FF453A';

  // Controls — keep fields readable over photo stage
  static readonly fieldBg: string = '#3DFFFFFF'; // ~24% white
  static readonly chipBg: string = '#2EFFFFFF';
  static readonly cardSelected: string = '#CC0A84FF'; // solid-enough selected card

  // Shape
  static readonly radiusSm: number = 12;
  static readonly radiusMd: number = 18;
  static readonly radiusLg: number = 28;
  static readonly radiusPill: number = 999;

  // Blur (ArkUI backdropBlur radius)
  static readonly blurPanel: number = 18;
  static readonly blurSoft: number = 12;
  static readonly blurStrong: number = 22;

  // Dark ink for light surfaces (meeting card, light map captions)
  static readonly inkOnLight: string = '#0F172A';
  static readonly inkOnLightMuted: string = '#475569';

  // ---- compatibility aliases (older pages) ----
  static readonly bg: string = '#07080C';
  static readonly bgElevated: string = '#12141C';
  static readonly card: string = '#B3121620';
  static readonly cardMuted: string = '#C2181C28';
  static readonly glass: string = '#B3121620';
  static readonly glassSoft: string = '#33FFFFFF';
  static readonly mapPanel: string = '#1A2332';
  static readonly primary: string = '#0A84FF';
  static readonly primaryDeep: string = '#0071E3';
  static readonly teal: string = '#64D2FF';
  static readonly tealDeep: string = '#0A84FF';
  static readonly blue: string = '#409CFF';
  static readonly purple: string = '#BF5AF2';
  static readonly amber: string = '#FF9F0A';
  static readonly pinkSoft: string = '#33FFD60A';
  static readonly text: string = '#F5F5F7';
  static readonly textSecondary: string = '#D9FFFFFF';
  static readonly textMuted: string = '#B3FFFFFF';
  static readonly textOnLight: string = '#0F172A';
  static readonly textOnLightSecondary: string = '#475569';
  static readonly textOnPrimary: string = '#FFFFFF';
  static readonly border: string = '#33FFFFFF';
  static readonly borderSoft: string = '#29FFFFFF';
  static readonly hairline: string = '#29FFFFFF';
}
