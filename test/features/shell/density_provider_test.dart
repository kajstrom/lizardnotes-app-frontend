import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/shell/providers/density_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DensityTokens', () {
    test('comfortable values match spec', () {
      final t = DensityTokens.comfortable();
      expect(t.rowPadY, 6);
      expect(t.rowPadX, 10);
      expect(t.rowGap, 2);
      expect(t.sidebarWidth, 240);
      expect(t.noteListWidth, 280);
      expect(t.editorPad, 48);
      expect(t.bodyFontSize, 15.5);
      expect(t.bodyLineHeight, 1.65);
      expect(t.chipPadY, 5);
      expect(t.chipPadX, 10);
    });

    test('compact values match spec', () {
      final t = DensityTokens.compact();
      expect(t.rowPadY, 3);
      expect(t.rowPadX, 8);
      expect(t.rowGap, 1);
      expect(t.sidebarWidth, 220);
      expect(t.noteListWidth, 260);
      expect(t.editorPad, 32);
      expect(t.bodyFontSize, 14);
      expect(t.bodyLineHeight, 1.55);
      expect(t.chipPadY, 3);
      expect(t.chipPadX, 8);
    });

    test('comfortable and compact values differ', () {
      final comfortable = DensityTokens.comfortable();
      final compact = DensityTokens.compact();

      expect(comfortable.sidebarWidth, isNot(compact.sidebarWidth));
      expect(comfortable.noteListWidth, isNot(compact.noteListWidth));
      expect(comfortable.editorPad, isNot(compact.editorPad));
      expect(comfortable.bodyFontSize, isNot(compact.bodyFontSize));
    });
  });

  group('DensityNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default state is comfortable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(densityProvider), DensityMode.comfortable);
    });

    test('toggle switches comfortable → compact and persists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(densityProvider), DensityMode.comfortable);

      await container.read(densityProvider.notifier).toggle();

      expect(container.read(densityProvider), DensityMode.compact);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ln:density'), 'compact');
    });

    test('toggle switches compact → comfortable and persists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // comfortable → compact
      await container.read(densityProvider.notifier).toggle();
      expect(container.read(densityProvider), DensityMode.compact);

      // compact → comfortable
      await container.read(densityProvider.notifier).toggle();
      expect(container.read(densityProvider), DensityMode.comfortable);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ln:density'), 'comfortable');
    });

    test('densityTokensProvider reflects the active mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(densityTokensProvider).sidebarWidth,
        DensityTokens.comfortable().sidebarWidth,
      );

      await container.read(densityProvider.notifier).toggle(); // → compact

      expect(
        container.read(densityTokensProvider).sidebarWidth,
        DensityTokens.compact().sidebarWidth,
      );
    });
  });
}
