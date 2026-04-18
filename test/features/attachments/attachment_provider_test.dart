import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/attachments/models/attachment.dart';
import 'package:lizardnotes_app/features/attachments/providers/attachment_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Attachment _meta(String id, {String filename = 'file.pdf'}) => Attachment(
      attachmentId: id,
      noteId: 'note1',
      filename: filename,
      mimeType: 'application/pdf',
      size: 123,
      createdAt: DateTime(2024),
    );

ProviderContainer _makeContainer(
  ApiClient client, {
  S3Uploader? uploader,
}) {
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      if (uploader != null) s3UploaderProvider.overrideWithValue(uploader),
    ],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  group('AttachmentNotifier.uploadAttachment', () {
    test('transitions uploading → complete on success', () async {
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

      final uploadCompleter = Completer<void>();
      final container = _makeContainer(
        client,
        uploader: ({required url, required bytes, required contentType, onProgress}) async {
          onProgress?.call(50, 100);
          await uploadCompleter.future;
        },
      );
      addTearDown(container.dispose);

      final future = container
          .read(attachmentProvider('note1').notifier)
          .uploadAttachment(
            filename: 'file.pdf',
            mimeType: 'application/pdf',
            bytes: Uint8List(10),
          );

      // Allow microtasks: createAttachment resolves, item inserted as uploading,
      // then onProgress reports 0.5.
      await Future<void>.delayed(Duration.zero);
      var state = container.read(attachmentProvider('note1'));
      expect(state.items, hasLength(1));
      expect(state.items.first.status, UploadStatus.uploading);
      expect(state.items.first.progress, 0.5);

      uploadCompleter.complete();
      await future;

      state = container.read(attachmentProvider('note1'));
      expect(state.items.first.status, UploadStatus.complete);
      expect(state.items.first.progress, 1.0);
    });

    test('transitions to failed on S3 error', () async {
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

      final container = _makeContainer(
        client,
        uploader: ({required url, required bytes, required contentType, onProgress}) async {
          throw Exception('network down');
        },
      );
      addTearDown(container.dispose);

      await container
          .read(attachmentProvider('note1').notifier)
          .uploadAttachment(
            filename: 'file.pdf',
            mimeType: 'application/pdf',
            bytes: Uint8List(10),
          );

      final state = container.read(attachmentProvider('note1'));
      expect(state.items.first.status, UploadStatus.failed);
      expect(state.items.first.error, contains('network down'));
    });
  });

  group('AttachmentNotifier.deleteAttachment', () {
    test('optimistically removes and rolls back on API error', () async {
      final client = MockApiClient();
      when(() => client.getAttachments(any()))
          .thenAnswer((_) async => [_meta('a1'), _meta('a2')]);
      when(() => client.deleteAttachment(
            noteId: any(named: 'noteId'),
            attachmentId: any(named: 'attachmentId'),
          )).thenThrow(const ApiException(500, 'err', 'deleteAttachment'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);

      await container
          .read(attachmentProvider('note1').notifier)
          .loadAttachments();
      expect(
        container.read(attachmentProvider('note1')).items,
        hasLength(2),
      );

      await container
          .read(attachmentProvider('note1').notifier)
          .deleteAttachment('a1');

      // Rolled back.
      final finalState = container.read(attachmentProvider('note1'));
      expect(finalState.items, hasLength(2));
      expect(
        finalState.items.map((i) => i.attachment.attachmentId),
        containsAll(['a1', 'a2']),
      );
    });

    test('removes item on API success', () async {
      final client = MockApiClient();
      when(() => client.getAttachments(any()))
          .thenAnswer((_) async => [_meta('a1'), _meta('a2')]);
      when(() => client.deleteAttachment(
            noteId: any(named: 'noteId'),
            attachmentId: any(named: 'attachmentId'),
          )).thenAnswer((_) async {});

      final container = _makeContainer(client);
      addTearDown(container.dispose);

      await container
          .read(attachmentProvider('note1').notifier)
          .loadAttachments();
      await container
          .read(attachmentProvider('note1').notifier)
          .deleteAttachment('a1');

      final ids = container
          .read(attachmentProvider('note1'))
          .items
          .map((i) => i.attachment.attachmentId);
      expect(ids, ['a2']);
    });
  });
}
