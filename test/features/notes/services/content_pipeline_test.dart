import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/notes/services/content_pipeline.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('ContentPipeline.toMarkdown', () {
    test('serialises ln-image embed with caption', () {
      final delta = Delta()
        ..insert({
          'ln-image': {
            'attachmentId': 'abc-123',
            'url': 'https://s3.example.com/signed/photo.jpg',
            'caption': 'My photo',
          }
        })
        ..insert('\n');
      final doc = Document.fromDelta(delta);

      final result = ContentPipeline.toMarkdown(doc);

      expect(result, contains('![My photo](attachment://abc-123)'));
    });

    test('serialises ln-image embed with empty caption', () {
      final delta = Delta()
        ..insert({
          'ln-image': {
            'attachmentId': 'abc-123',
            'url': 'https://s3.example.com/signed/photo.jpg',
            'caption': '',
          }
        })
        ..insert('\n');
      final doc = Document.fromDelta(delta);

      final result = ContentPipeline.toMarkdown(doc);

      expect(result, contains('![](attachment://abc-123)'));
    });

    test('preserves surrounding text when embedding an image', () {
      final delta = Delta()
        ..insert('Before')
        ..insert('\n')
        ..insert({
          'ln-image': {
            'attachmentId': 'img-1',
            'url': 'https://s3.example.com/img.png',
            'caption': 'A shot',
          }
        })
        ..insert('\n')
        ..insert('After')
        ..insert('\n');
      final doc = Document.fromDelta(delta);

      final result = ContentPipeline.toMarkdown(doc);

      final idxBefore = result.indexOf('Before');
      final idxImage = result.indexOf('![A shot](attachment://img-1)');
      final idxAfter = result.indexOf('After');
      expect(idxBefore, lessThan(idxImage));
      expect(idxImage, lessThan(idxAfter));
    });
  });

  group('ContentPipeline.fromMarkdown', () {
    test('returns empty document for empty string', () async {
      final doc = await ContentPipeline.fromMarkdown('');
      expect(doc.isEmpty(), isTrue);
    });

    test('makes no API calls when markdown has no attachment:// refs', () async {
      final api = MockApiClient();
      final doc = await ContentPipeline.fromMarkdown(
        'Hello **world**',
        noteId: 'note-1',
        api: api,
      );
      verifyNever(() => api.getAttachmentDownloadUrl(
            noteId: any(named: 'noteId'),
            attachmentId: any(named: 'attachmentId'),
          ));
      expect(doc.toPlainText(), contains('Hello'));
    });

    test('resolves attachment:// ref and builds ln-image embed', () async {
      const markdown = '![My caption](attachment://img-abc)\n';
      final api = MockApiClient();
      when(() => api.getAttachmentDownloadUrl(
            noteId: 'note-1',
            attachmentId: 'img-abc',
          )).thenAnswer((_) async => 'https://s3.example.com/signed/photo.jpg');

      final doc = await ContentPipeline.fromMarkdown(
        markdown,
        noteId: 'note-1',
        api: api,
      );

      final imageOps = doc.toDelta().toList().where((op) {
        final d = op.data;
        return d is Map && d.containsKey('ln-image');
      }).toList();
      expect(imageOps, hasLength(1));
      final embed = (imageOps.first.data as Map)['ln-image'] as Map;
      expect(embed['attachmentId'], 'img-abc');
      expect(embed['url'], 'https://s3.example.com/signed/photo.jpg');
      expect(embed['caption'], 'My caption');
    });

    test('gracefully handles failed URL fetch — embed created with empty url', () async {
      const markdown = '![photo](attachment://bad-id)\n';
      final api = MockApiClient();
      when(() => api.getAttachmentDownloadUrl(
            noteId: 'note-1',
            attachmentId: 'bad-id',
          )).thenThrow(Exception('not found'));

      final doc = await ContentPipeline.fromMarkdown(
        markdown,
        noteId: 'note-1',
        api: api,
      );

      final imageOps = doc.toDelta().toList().where((op) {
        final d = op.data;
        return d is Map && d.containsKey('ln-image');
      }).toList();
      expect(imageOps, hasLength(1));
      final embed = (imageOps.first.data as Map)['ln-image'] as Map;
      expect(embed['attachmentId'], 'bad-id');
      expect(embed['url'], '');
    });
  });
}
