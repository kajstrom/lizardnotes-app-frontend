import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/services/content_pipeline.dart';

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
}
