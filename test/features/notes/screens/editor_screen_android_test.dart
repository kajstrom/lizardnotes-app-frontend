import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/attachments/models/attachment.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/notes/models/note.dart';
import 'package:lizardnotes_app/features/notes/providers/selected_note_provider.dart';
import 'package:lizardnotes_app/features/notes/widgets/format_toolbar.dart';
import 'package:lizardnotes_app/router/app_router.dart';
import 'package:lizardnotes_app/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Pins the selected note so EditorScreen renders instead of bouncing back to
/// the folder list (which it does whenever no note is selected on mobile).
class _FixedSelectedNote extends SelectedNoteNotifier {
  _FixedSelectedNote(this.initial);

  final String initial;

  @override
  String? build() => initial;
}

/// Status bar / gesture nav bar insets typical of an Android phone.
const _statusBarHeight = 24.0;
const _navBarHeight = 48.0;
const _screenSize = Size(390, 844);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final note = Note(
    noteId: 'n1',
    folderId: 'f1',
    title: 'N1',
    content: 'hello',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  MockApiClient stubClient({List<Note> notesInFolder = const []}) {
    final client = MockApiClient();
    when(() => client.getFolders()).thenAnswer(
      (_) async => [
        Folder(
          folderId: 'f1',
          name: 'F1',
          path: '/F1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ],
    );
    when(() => client.getNotes(folderId: any(named: 'folderId')))
        .thenAnswer((_) async => notesInFolder);
    when(() => client.getNote(any())).thenAnswer((_) async => note);
    when(() => client.getAttachments(any()))
        .thenAnswer((_) async => <Attachment>[]);
    return client;
  }

  void applyAndroidViewport(WidgetTester tester) {
    tester.view.physicalSize = _screenSize;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBarHeight,
      bottom: _navBarHeight,
    );
    tester.view.padding = const FakeViewPadding(
      top: _statusBarHeight,
      bottom: _navBarHeight,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
  }

  Future<GoRouter> pumpApp(WidgetTester tester, MockApiClient client) async {
    applyAndroidViewport(tester);

    final notifier = ValueNotifier<bool>(true);
    final router = AppRouter.buildRouter(notifier);
    addTearDown(router.dispose);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          selectedNoteIdProvider.overrideWith(() => _FixedSelectedNote('n1')),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Walks the real mobile flow: folder list → note list → editor, so the note
  /// provider is populated exactly as it would be on a device.
  Future<GoRouter> pumpEditorViaNoteList(WidgetTester tester) async {
    final router = await pumpApp(
      tester,
      stubClient(notesInFolder: [note]),
    );
    router.go('/app/folders/f1');
    await tester.pumpAndSettle();
    router.go('/app/notes/n1');
    await tester.pumpAndSettle();
    return router;
  }

  group('EditorScreen on Android — system back button', () {
    testWidgets(
      'system back returns to the note list instead of exiting the app',
      (tester) async {
        final router = await pumpEditorViaNoteList(tester);

        expect(
          _location(router),
          '/app/notes/n1',
          reason: 'precondition: the editor is the current route',
        );

        // This is exactly what the Android back button triggers: the engine
        // sends popRoute to the Router. Returning false means "nothing to pop"
        // and Android finishes the activity — i.e. the app exits.
        final handled = await router.routerDelegate.popRoute();
        await tester.pumpAndSettle();

        expect(
          handled,
          isTrue,
          reason: 'the app must handle back itself rather than letting Android '
              'finish the activity',
        );
        expect(
          _location(router),
          '/app/folders/f1',
          reason: "back should land on the note list for the note's folder",
        );
      },
    );

    testWidgets(
      'system back falls back to the folder list on a cold deep link',
      (tester) async {
        // Editor opened directly (session restore / deep link): the note
        // provider was never populated, so no folder context is available.
        final router = await pumpApp(tester, stubClient());
        router.go('/app/notes/n1');
        await tester.pumpAndSettle();

        final handled = await router.routerDelegate.popRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(_location(router), '/app/folders');
      },
    );
  });

  group('EditorScreen on Android — safe area insets', () {
    testWidgets(
      'topbar controls are not hidden behind the status bar',
      (tester) async {
        await pumpEditorViaNoteList(tester);

        final back = find.byIcon(Icons.chevron_left);
        final actions = find.byIcon(Icons.more_horiz);
        expect(back, findsOneWidget);
        expect(actions, findsOneWidget);

        for (final entry in [
          ('back chevron', back),
          ('actions menu', actions),
        ]) {
          expect(
            tester.getRect(entry.$2).top,
            greaterThanOrEqualTo(_statusBarHeight),
            reason: '${entry.$1} must sit below the status bar to be tappable',
          );
        }
      },
    );

    testWidgets(
      'topbar tap target clears the status bar entirely',
      (tester) async {
        await pumpEditorViaNoteList(tester);

        // The whole 44px button, not just the glyph, must be reachable.
        final button = find
            .ancestor(
              of: find.byIcon(Icons.chevron_left),
              matching: find.byType(IconButton),
            )
            .first;
        expect(
          tester.getRect(button).top,
          greaterThanOrEqualTo(_statusBarHeight),
          reason: 'the back button tap target must clear the status bar',
        );
      },
    );

    testWidgets(
      'docked format toolbar stays clear of the gesture nav bar',
      (tester) async {
        await pumpEditorViaNoteList(tester);

        final toolbar = find.byType(FormatToolbar);
        expect(toolbar, findsOneWidget);
        expect(
          tester.getRect(toolbar).bottom,
          lessThanOrEqualTo(_screenSize.height - _navBarHeight),
          reason: 'the format toolbar must not sit under the gesture nav bar',
        );
      },
    );
  });
}
