import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/search/utils/highlight_builder.dart';

void main() {
  const normal = TextStyle(color: Colors.white);
  const highlight = TextStyle(color: Colors.purple, fontWeight: FontWeight.bold);

  group('buildHighlightSpans', () {
    test('no matches → single unstyled span', () {
      final spans = buildHighlightSpans('hello world', const [],
          normalStyle: normal, highlightStyle: highlight);
      expect(spans, hasLength(1));
      expect(spans[0].text, 'hello world');
      expect(spans[0].style, normal);
    });

    test('match at start of string', () {
      final spans = buildHighlightSpans(
        'hello world',
        [const TextRange(start: 0, end: 5)],
        normalStyle: normal,
        highlightStyle: highlight,
      );
      expect(spans, hasLength(2));
      expect(spans[0].text, 'hello');
      expect(spans[0].style, highlight);
      expect(spans[1].text, ' world');
      expect(spans[1].style, normal);
    });

    test('match at end of string', () {
      final spans = buildHighlightSpans(
        'hello world',
        [const TextRange(start: 6, end: 11)],
        normalStyle: normal,
        highlightStyle: highlight,
      );
      expect(spans, hasLength(2));
      expect(spans[0].text, 'hello ');
      expect(spans[0].style, normal);
      expect(spans[1].text, 'world');
      expect(spans[1].style, highlight);
    });

    test('match in middle produces plain/highlight/plain', () {
      final spans = buildHighlightSpans(
        'say hello there',
        [const TextRange(start: 4, end: 9)],
        normalStyle: normal,
        highlightStyle: highlight,
      );
      expect(spans, hasLength(3));
      expect(spans[0].text, 'say ');
      expect(spans[1].text, 'hello');
      expect(spans[1].style, highlight);
      expect(spans[2].text, ' there');
    });

    test('multiple non-overlapping matches', () {
      final spans = buildHighlightSpans(
        'aabbaabb',
        [
          const TextRange(start: 0, end: 2),
          const TextRange(start: 4, end: 6),
        ],
        normalStyle: normal,
        highlightStyle: highlight,
      );
      expect(spans, hasLength(4));
      expect(spans[0].text, 'aa');
      expect(spans[0].style, highlight);
      expect(spans[1].text, 'bb');
      expect(spans[1].style, normal);
      expect(spans[2].text, 'aa');
      expect(spans[2].style, highlight);
      expect(spans[3].text, 'bb');
      expect(spans[3].style, normal);
    });

    test('overlapping / out-of-order ranges do not crash', () {
      expect(
        () => buildHighlightSpans(
          'hello',
          // Overlapping: second range starts before first ends.
          [
            const TextRange(start: 0, end: 3),
            const TextRange(start: 2, end: 5),
          ],
          normalStyle: normal,
          highlightStyle: highlight,
        ),
        returnsNormally,
      );
    });

    test('empty string returns single empty span', () {
      final spans = buildHighlightSpans('', const [],
          normalStyle: normal, highlightStyle: highlight);
      expect(spans, hasLength(1));
      expect(spans[0].text, '');
    });
  });
}
