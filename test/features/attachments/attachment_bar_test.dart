import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/attachments/models/attachment.dart';
import 'package:lizardnotes_app/features/attachments/providers/attachment_provider.dart';
import 'package:lizardnotes_app/features/attachments/widgets/attachment_bar.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Attachment _meta(String id) => Attachment(
      attachmentId: id,
      noteId: 'n1',
      filename: 'photo_1.jpg',
      mimeType: 'image/jpeg',
      size: 10,
      createdAt: DateTime(2024),
    );

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: AttachmentBar(noteId: 'n1')),
      ),
    );

Finder _trigger() => find.widgetWithText(InkWell, 'take photo');

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  testWidgets('tapping take photo uploads a jpeg attachment', (tester) async {
    final client = MockApiClient();
    when(() => client.createAttachment(
          noteId: any(named: 'noteId'),
          filename: any(named: 'filename'),
          mimeType: any(named: 'mimeType'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => CreateAttachmentResult(
          attachment: _meta('a1'),
          uploadUrl: 'https://s3/put',
        ));

    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      s3UploaderProvider.overrideWithValue(
        ({required url, required source, required contentType, onProgress}) async {},
      ),
      cameraPickerProvider.overrideWithValue(
        () async => XFile.fromData(Uint8List(4), mimeType: 'image/jpeg'),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(_trigger());
    await tester.pumpAndSettle();

    final captured = verify(() => client.createAttachment(
          noteId: any(named: 'noteId'),
          filename: captureAny(named: 'filename'),
          mimeType: captureAny(named: 'mimeType'),
          size: any(named: 'size'),
        )).captured;
    expect(captured[0], matches(RegExp(r'^photo_\d+\.jpg$')));
    expect(captured[1], 'image/jpeg');

    // Let the notifier's 3s complete→idle revert timer fire so it doesn't
    // leak past the end of the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('cancelling the picker does not upload', (tester) async {
    final client = MockApiClient();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      cameraPickerProvider.overrideWithValue(() async => null),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(_trigger());
    await tester.pumpAndSettle();

    verifyNever(() => client.createAttachment(
          noteId: any(named: 'noteId'),
          filename: any(named: 'filename'),
          mimeType: any(named: 'mimeType'),
          size: any(named: 'size'),
        ));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('camera permission denial shows a specific message',
      (tester) async {
    final client = MockApiClient();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      cameraPickerProvider.overrideWithValue(
        () async => throw PlatformException(code: 'camera_access_denied'),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(_trigger());
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera permission denied'), findsOneWidget);
  });

  testWidgets('other picker failure shows a generic message', (tester) async {
    final client = MockApiClient();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      cameraPickerProvider.overrideWithValue(
        () async => throw PlatformException(code: 'no_available_camera'),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(_trigger());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open camera'), findsOneWidget);
  });

  testWidgets('shows a busy spinner while the picker is in flight and disables the trigger',
      (tester) async {
    final client = MockApiClient();
    final completer = Completer<XFile?>();
    var pickCalls = 0;
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      cameraPickerProvider.overrideWithValue(() {
        pickCalls++;
        return completer.future;
      }),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container));
    await tester.tap(_trigger());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(pickCalls, 1);
    expect(tester.widget<InkWell>(_trigger()).onTap, isNull);

    completer.complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(pickCalls, 1);
  });
}
