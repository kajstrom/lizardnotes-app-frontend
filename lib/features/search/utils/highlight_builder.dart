import 'package:flutter/widgets.dart';

/// Splits [text] at the given match [ranges] and returns a list of
/// [TextSpan]s. Matched substrings are styled with [highlightStyle];
/// unmatched text uses [normalStyle].
///
/// Ranges must be non-overlapping and sorted by start offset. If a range
/// falls outside the string bounds it is silently skipped.
List<TextSpan> buildHighlightSpans(
  String text,
  List<TextRange> ranges, {
  required TextStyle normalStyle,
  required TextStyle highlightStyle,
}) {
  if (ranges.isEmpty) return [TextSpan(text: text, style: normalStyle)];

  final spans = <TextSpan>[];
  var cursor = 0;

  for (final range in ranges) {
    final start = range.start.clamp(0, text.length);
    final end = range.end.clamp(0, text.length);
    if (start >= end || start < cursor) continue;

    if (start > cursor) {
      spans.add(TextSpan(
        text: text.substring(cursor, start),
        style: normalStyle,
      ));
    }
    spans.add(TextSpan(
      text: text.substring(start, end),
      style: highlightStyle,
    ));
    cursor = end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: normalStyle));
  }

  return spans.isEmpty ? [TextSpan(text: text, style: normalStyle)] : spans;
}
