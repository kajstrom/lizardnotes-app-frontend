import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/shell/desktop_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildShell({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: DesktopShell(child: Container()),
      ),
    );
  }

  group('DesktopShell note-list column', () {
    testWidgets('AnimatedContainer width is 280 px when visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildShell(container: container));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(DesktopShell.noteListColumnKey));
      expect(size.width, 280.0);
    });

    testWidgets('AnimatedContainer width is 0 px when hidden', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildShell(container: container));
      await tester.pumpAndSettle();

      // Hide the note list via the provider.
      container.read(noteListVisibleProvider.notifier).setValue(false);

      // Advance past the 180 ms animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final size = tester.getSize(find.byKey(DesktopShell.noteListColumnKey));
      expect(size.width, 0.0);
    });
  });
}
