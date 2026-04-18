import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DensityMode { comfortable, compact }

/// All density-dependent dimension values derived from the active [DensityMode].
/// Mirrors the token table in IMPLEMENTATION.md §4.
class DensityTokens {
  const DensityTokens._({
    required this.rowPadY,
    required this.rowPadX,
    required this.rowGap,
    required this.sidebarWidth,
    required this.noteListWidth,
    required this.editorPad,
    required this.bodyFontSize,
    required this.bodyLineHeight,
    required this.chipPadY,
    required this.chipPadX,
  });

  factory DensityTokens.comfortable() => const DensityTokens._(
    rowPadY: 6,
    rowPadX: 10,
    rowGap: 2,
    sidebarWidth: 240,
    noteListWidth: 280,
    editorPad: 48,
    bodyFontSize: 15.5,
    bodyLineHeight: 1.65,
    chipPadY: 5,
    chipPadX: 10,
  );

  factory DensityTokens.compact() => const DensityTokens._(
    rowPadY: 3,
    rowPadX: 8,
    rowGap: 1,
    sidebarWidth: 220,
    noteListWidth: 260,
    editorPad: 32,
    bodyFontSize: 14,
    bodyLineHeight: 1.55,
    chipPadY: 3,
    chipPadX: 8,
  );

  final double rowPadY;
  final double rowPadX;
  final double rowGap;
  final double sidebarWidth;
  final double noteListWidth;
  final double editorPad;
  final double bodyFontSize;
  final double bodyLineHeight;
  final double chipPadY;
  final double chipPadX;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final densityProvider =
    NotifierProvider<DensityNotifier, DensityMode>(DensityNotifier.new);

/// Derived provider — gives the [DensityTokens] for the active mode.
final densityTokensProvider = Provider<DensityTokens>((ref) {
  return switch (ref.watch(densityProvider)) {
    DensityMode.comfortable => DensityTokens.comfortable(),
    DensityMode.compact => DensityTokens.compact(),
  };
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DensityNotifier extends Notifier<DensityMode> {
  static const _prefsKey = 'ln:density';

  @override
  DensityMode build() {
    _loadFromPrefs();
    return DensityMode.comfortable;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == DensityMode.compact.name) state = DensityMode.compact;
  }

  Future<void> toggle() async {
    final next = state == DensityMode.comfortable
        ? DensityMode.compact
        : DensityMode.comfortable;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next.name);
  }
}
