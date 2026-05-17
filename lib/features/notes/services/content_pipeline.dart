import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

/// Converts between the markdown strings stored in DynamoDB and the Quill
/// Delta format used internally by flutter_quill.
///
/// Supported block types: paragraphs, h2/h3, ul/ol, blockquote, inline code,
/// code blocks, bold, italic, links.
/// h1 is intentionally excluded — the title TextField serves as h1.
///
/// Known limitations:
/// - DeltaToMarkdown escapes special markdown characters (e.g. `.` → `\.`),
///   so the output markdown may contain backslash-escaped punctuation.
/// - Nested lists and complex inline HTML may degrade to plain text.
class ContentPipeline {
  ContentPipeline._();

  static final _mdToQuill = MarkdownToDelta(
    markdownDocument: md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ),
  );

  static final _quillToMd = DeltaToMarkdown();

  static Document fromMarkdown(String markdown) {
    if (markdown.trim().isEmpty) return Document();
    try {
      final delta = _mdToQuill.convert(markdown);
      return Document.fromDelta(delta);
    } catch (_) {
      // Fallback: treat unsupported content as plain text rather than crashing.
      return Document()..insert(0, markdown);
    }
  }

  static String toMarkdown(Document doc) {
    try {
      return _deltaToMarkdown(doc.toDelta());
    } catch (_) {
      return doc.toPlainText();
    }
  }

  // Iterates ops; when an ln-image embed is found it flushes the accumulated
  // sub-delta to DeltaToMarkdown and writes the image line directly.
  static String _deltaToMarkdown(Delta delta) {
    final result = StringBuffer();
    final pendingOps = <Operation>[];

    void flushPending() {
      if (pendingOps.isEmpty) return;
      result.write(_quillToMd.convert(Delta.fromOperations(pendingOps)));
      pendingOps.clear();
    }

    final ops = delta.toList();
    int i = 0;
    while (i < ops.length) {
      final op = ops[i];
      final data = op.data;
      if (data is Map && data.containsKey('ln-image')) {
        flushPending();
        final embed = Map<String, dynamic>.from(data['ln-image'] as Map);
        final id = embed['attachmentId'] as String;
        final caption = (embed['caption'] as String?) ?? '';
        result.write('![$caption](attachment://$id)\n\n');
        // Skip the block-terminator \n that follows the embed, if present.
        if (i + 1 < ops.length && ops[i + 1].data == '\n') i++;
      } else {
        pendingOps.add(op);
      }
      i++;
    }
    flushPending();
    return result.toString();
  }
}
