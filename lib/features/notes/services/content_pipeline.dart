import 'package:flutter_quill/flutter_quill.dart';
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
      return _quillToMd.convert(doc.toDelta());
    } catch (_) {
      return doc.toPlainText();
    }
  }
}
