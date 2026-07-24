/**
 * Liquid-glass tokens ported from liquid-glass (Apple TV stage + frosted controls).
 * Harmony Color strings: prefer #AARRGGBB when alpha is needed.
 */

export class AppTheme {
  // Stage
  static readonly bg0: string = '#07080C';
  static readonly bg1: string = '#12141C';

  // Ink on glass
  static readonly ink: string = '#F5F5F7';
  static readonly inkMuted: string = '#ADFFFFFF';
  static readonly inkSoft: string = '#75FFFFFF';
  static readonly inkFaint: string = '#59FFFFFF';

  // Lines
  static readonly line: string = '#1AFFFFFF';
  static readonly lineStrong: string = '#2EFFFFFF';
  static readonly lineFocus: string = '#B30A84FF';

  // Accent
  static readonly accent: string = '#0A84FF';
  static readonly accentStrong: string = '#409CFF';
  static readonly accentSoft: string = '#2E0A84FF';
  static readonly accentGlow: string = '#470A84FF';
  static readonly link: string = '#64D2FF';
  static readonly success: string = '#30D158';
  static readonly warn: string = '#FF9F0A';
  static readonly danger: string = '#FF453A';

  // Glass fills
  static readonly glassBg: string = '#850C1018';
  static readonly glassBgStrong: string = '#9E10141E';
  static readonly glassBgLight: string = '#24FFFFFF';
  static readonly glassBgLighter: string = '#14FFFFFF';
  static readonly glassBorder: string = '#29FFFFFF';
  static readonly glassHighlight: string = '#38FFFFFF';

  // Controls
  static readonly fieldBg: string = '#0FFFFFFF';
  static readonly chipBg: string = '#14FFFFFF';
  static readonly cardSelected: string = '#330A84FF';

  // Shape
  static readonly radiusSm: number = 12;
  static readonly radiusMd: number = 18;
  static readonly radiusLg: number = 28;
  static readonly radiusPill: number = 999;

  // Blur (ArkUI backdropBlur radius)
  static readonly blurPanel: number = 18;
  static readonly blurSoft: number = 12;
  static readonly blurStrong: number = 22;

  // ---- compatibility aliases (older pages) ----
  static readonly bg: string = '#07080C';
  static readonly bgElevated: string = '#12141C';
  static readonly card: string = '#850C1018';
  static readonly cardMuted: string = '#9E10141E';
  static readonly glass: string = '#850C1018';
  static readonly glassSoft: string = '#24FFFFFF';
  static readonly mapPanel: string = '#E8EEF5';
  static readonly primary: string = '#0A84FF';
  static readonly primaryDeep: string = '#0071E3';
  static readonly teal: string = '#64D2FF';
  static readonly tealDeep: string = '#0A84FF';
  static readonly blue: string = '#409CFF';
  static readonly purple: string = '#BF5AF2';
  static readonly amber: string = '#FF9F0A';
  static readonly pinkSoft: string = '#33FFD60A';
  static readonly text: string = '#F5F5F7';
  static readonly textSecondary: string = '#ADFFFFFF';
  static readonly textMuted: string = '#75FFFFFF';
  static readonly textOnLight: string = '#F5F5F7';
  static readonly textOnLightSecondary: string = '#ADFFFFFF';
  static readonly textOnPrimary: string = '#FFFFFF';
  static readonly border: string = '#1AFFFFFF';
  static readonly borderSoft: string = '#1AFFFFFF';
  static readonly hairline: string = '#1AFFFFFF';
}
