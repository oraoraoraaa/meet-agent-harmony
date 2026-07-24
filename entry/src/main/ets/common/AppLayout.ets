/**
 * Shared layout insets for immersive full-screen window.
 * Stage/background expands under system bars; chrome must pad content.
 */
export class AppLayout {
  /**
   * Top inset so titles/buttons clear status bar + punch-hole.
   * Window is full-screen (EntryAbility); do not rely on default safe area alone.
   */
  static readonly statusBarInsetVp: number = 44;

  /** Extra breathing room under the status inset for page headers. */
  static readonly headerTopPadVp: number = 8;

  /** Convenient total top padding for a header row. */
  static headerTop(): number {
    return AppLayout.statusBarInsetVp + AppLayout.headerTopPadVp;
  }
}
