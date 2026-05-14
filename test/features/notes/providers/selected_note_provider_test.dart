import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/providers/selected_note_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SelectedNoteNotifier.select', () {
    test('sets state immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedNoteIdProvider.notifier).select('note-1');

      expect(container.read(selectedNoteIdProvider), 'note-1');
    });

    test('persists id to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedNoteIdProvider.notifier).select('note-1');
      // Let the fire-and-forget .then() complete.
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastSelectedNoteId'), 'note-1');
    });

    test('select(null) clears state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedNoteIdProvider.notifier).select('note-1');
      container.read(selectedNoteIdProvider.notifier).select(null);

      expect(container.read(selectedNoteIdProvider), isNull);
    });

    test('select(null) removes key from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(
          {'lastSelectedNoteId': 'note-1'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedNoteIdProvider.notifier).select(null);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastSelectedNoteId'), isNull);
    });
  });

  group('SelectedNoteNotifier.restoreFromPrefs', () {
    test('sets state from persisted value', () async {
      SharedPreferences.setMockInitialValues(
          {'lastSelectedNoteId': 'note-abc'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(selectedNoteIdProvider.notifier)
          .restoreFromPrefs();

      expect(container.read(selectedNoteIdProvider), 'note-abc');
    });

    test('does nothing when no value is persisted', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(selectedNoteIdProvider.notifier)
          .restoreFromPrefs();

      expect(container.read(selectedNoteIdProvider), isNull);
    });
  });
}
