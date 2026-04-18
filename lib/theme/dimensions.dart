/// Named spacing and radius constants.
///
/// Density values default to "comfortable". Where a compact alternative exists
/// it is listed beside the comfortable value.
abstract final class LnDims {
  // ── Comfortable density defaults ───────────────────────────────────────────
  static const double rowPadY = 6;      // compact: 3
  static const double rowPadX = 10;     // compact: 8
  static const double rowGap = 2;       // compact: 1
  static const double sidebarWidth = 240;  // compact: 220
  static const double noteListWidth = 280; // compact: 260
  static const double editorPad = 48;   // compact: 32
  static const double bodyFontSize = 15.5; // compact: 14
  static const double bodyLineHeight = 1.65; // compact: 1.55
  static const double chipPadY = 5;     // compact: 3
  static const double chipPadX = 10;    // compact: 8

  // ── Radii ──────────────────────────────────────────────────────────────────
  /// kbd hints, small form pills, inline code background.
  static const double r4 = 4;
  /// chips, note cards, segmented controls, menu items.
  static const double r5 = 5;
  /// inputs, buttons, info boxes, sidebar search, note card hover border.
  static const double r6 = 6;
  /// context menus.
  static const double r7 = 7;
  /// dropzones, QR code wrapper.
  static const double r8 = 8;
  /// modals, Tweaks panel.
  static const double r10 = 10;
  /// auth card, Android screen inner radius.
  static const double r12 = 12;
}
