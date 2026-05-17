import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/services/content_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentPipeline.fromMarkdown', () {
    test('empty string returns empty document', () async {
      final doc = await ContentPipeline.fromMarkdown('');
      expect(doc.toPlainText().trim(), isEmpty);
    });

    test('does not crash on unsupported content', () async {
      // Should fall back to plain text rather than throwing.
      final doc = await ContentPipeline.fromMarkdown(
        '<div class="complex">HTML content</div>',
      );
      expect(doc, isA<Document>());
    });
  });

  group('ContentPipeline round-trip', () {
    // Each test converts markdown → Delta → markdown and checks that the
    // key semantic content is preserved in the output.

    test('plain paragraph', () async {
      const md = 'Hello, world.';
      final result = await _roundTrip(md);
      // DeltaToMarkdown escapes punctuation (e.g. '.' → '\.'), so check
      // for the core word content rather than exact string equality.
      expect(result, contains('Hello, world'));
    });

    test('bold inline', () async {
      const md = 'This is **bold** text.';
      final result = await _roundTrip(md);
      expect(result, contains('bold'));
      // Bold markers should be present in the output.
      expect(result, contains('**'));
    });

    test('italic inline', () async {
      const md = 'This is *italic* text.';
      final result = await _roundTrip(md);
      expect(result, contains('italic'));
      expect(result, anyOf(contains('*'), contains('_')));
    });

    test('h2 heading', () async {
      const md = '## Section Heading';
      final result = await _roundTrip(md);
      expect(result, contains('Section Heading'));
      expect(result, contains('##'));
    });

    test('h3 heading', () async {
      const md = '### Sub Heading';
      final result = await _roundTrip(md);
      expect(result, contains('Sub Heading'));
      expect(result, contains('###'));
    });

    test('unordered list', () async {
      const md = '- Apple\n- Banana\n- Cherry';
      final result = await _roundTrip(md);
      expect(result, contains('Apple'));
      expect(result, contains('Banana'));
      expect(result, contains('Cherry'));
    });

    test('ordered list', () async {
      const md = '1. First\n2. Second\n3. Third';
      final result = await _roundTrip(md);
      expect(result, contains('First'));
      expect(result, contains('Second'));
      expect(result, contains('Third'));
    });

    test('blockquote', () async {
      const md = '> This is a quote.';
      final result = await _roundTrip(md);
      expect(result, contains('This is a quote'));
    });

    test('inline code', () async {
      const md = 'Use `print()` to debug.';
      final result = await _roundTrip(md);
      expect(result, contains('print()'));
    });

    test('code block', () async {
      const md = '```\nconst x = 1;\n```';
      final result = await _roundTrip(md);
      expect(result, contains('const x = 1;'));
    });

    test('double quotes round-trip without HTML encoding', () async {
      const md = 'She said "hello world".';
      final result = await _roundTrip(md);
      expect(result, contains('"hello world"'));
      expect(result, isNot(contains('&quot;')));
    });

    test('ampersand round-trip without HTML encoding', () async {
      const md = 'Fish & chips.';
      final result = await _roundTrip(md);
      expect(result, contains('Fish'));
      expect(result, contains('chips'));
      expect(result, isNot(contains('&amp;')));
    });

    test('multiple blocks preserve all content', () async {
      const md = '''
## Heading

Paragraph text.

- Item one
- Item two
''';
      final result = await _roundTrip(md);
      expect(result, contains('Heading'));
      expect(result, contains('Paragraph text'));
      expect(result, contains('Item one'));
      expect(result, contains('Item two'));
    });
  });

  group('ContentPipeline.toMarkdown', () {
    test('empty document returns minimal output', () {
      final doc = Document();
      final result = ContentPipeline.toMarkdown(doc);
      expect(result, isA<String>());
    });

    test('plain text document round-trips', () {
      final doc = Document()..insert(0, 'Hello');
      final md = ContentPipeline.toMarkdown(doc);
      expect(md, contains('Hello'));
    });
  });
}

Future<String> _roundTrip(String markdown) async {
  final doc = await ContentPipeline.fromMarkdown(markdown);
  return ContentPipeline.toMarkdown(doc);
}
