import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:lizardnotes_app/api/api_client.dart';
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

  // Handles escape sequences in alt-text (e.g. \] for literal bracket).
  static final _attachmentRef =
      RegExp(r'!\[((?:[^\]\\]|\\.)*)\]\(attachment://([^)]+)\)');

  static String _escapeAltText(String s) => s
      .replaceAll(r'\', r'\\') // must be first
      .replaceAll(']', r'\]')
      .replaceAll('\n', ' ')
      .replaceAll('\r', '');

  static String _unescapeAltText(String s) =>
      s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);

  static Future<Document> fromMarkdown(
    String markdown, {
    String? noteId,
    ApiClient? api,
  }) async {
    if (markdown.trim().isEmpty) return Document();

    final matches = _attachmentRef.allMatches(markdown).toList();

    // Build a lookup: attachmentId → ordered captions (one per occurrence).
    // Using a queue so the same attachment embedded multiple times with
    // different captions round-trips correctly — each occurrence consumes
    // its own caption in document order.
    final idToCaption = <String, Queue<String>>{};
    for (final m in matches) {
      idToCaption
          .putIfAbsent(m.group(2)!, Queue<String>.new)
          .add(_unescapeAltText(m.group(1) ?? ''));
    }
    final idToUrl = <String, String>{};

    if (matches.isNotEmpty && noteId != null && api != null) {
      final uniqueIds = idToCaption.keys.toList();
      final urlEntries = await Future.wait(
        uniqueIds.map((id) async {
          try {
            final url = await api.getAttachmentDownloadUrl(
              noteId: noteId,
              attachmentId: id,
            );
            return MapEntry(id, url);
          } catch (_) {
            return MapEntry(id, '');
          }
        }),
      );
      idToUrl.addEntries(urlEntries);
    }

    try {
      // Replace attachment:// URLs with resolved presigned URLs so that
      // MarkdownToDelta can parse them as standard image operations.
      // A single replaceAllMapped pass avoids prefix-collision bugs
      // (e.g. id-1 matching inside id-10).
      final urlToId = <String, String>{};
      final processedMarkdown = markdown.replaceAllMapped(_attachmentRef, (m) {
        final id = m.group(2)!;
        final url = idToUrl[id];
        if (url != null && url.isNotEmpty) {
          urlToId[url] = id;
          // Alt-text content is recovered from idToCaption; keep it as-is.
          return '![${m.group(1) ?? ''}]($url)';
        }
        // No presigned URL — keep the attachment:// form; post-processing
        // will still convert this to an ln-image embed.
        urlToId['attachment://$id'] = id;
        return m.group(0)!;
      });

      final delta = _mdToQuill.convert(processedMarkdown);

      // Post-process delta: image ops whose URL maps to one of our attachment
      // IDs are converted to ln-image embeds.
      final processedOps = <Operation>[];
      for (final op in delta.toList()) {
        final data = op.data;
        if (data is Map) {
          final imageUrl = data['image'] as String?;
          if (imageUrl != null) {
            String? id = urlToId[imageUrl];
            if (id == null && imageUrl.startsWith('attachment://')) {
              id = imageUrl.substring('attachment://'.length);
            }
            if (id != null) {
              final queue = idToCaption[id];
              processedOps.add(Operation.insert({
                'ln-image': {
                  'attachmentId': id,
                  'url': idToUrl[id] ?? '',
                  'caption': (queue?.isNotEmpty == true)
                      ? queue!.removeFirst()
                      : '',
                },
              }));
              continue;
            }
          }
        }
        processedOps.add(op);
      }

      return Document.fromDelta(Delta.fromOperations(processedOps));
    } catch (e, st) {
      debugPrint('ContentPipeline.fromMarkdown failed: $e\n$st');
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
        final embed = Map<String, dynamic>.from(data['ln-image'] as Map);
        final id = embed['attachmentId'] as String? ?? '';
        if (id.isEmpty) {
          pendingOps.add(op);
          i++;
          continue;
        }
        flushPending();
        final caption = (embed['caption'] as String?) ?? '';
        result.write('![${_escapeAltText(caption)}](attachment://$id)\n\n');
        // Skip the block-terminator \n that follows the embed, if present,
        // but only if it carries no block-level formatting attributes.
        if (i + 1 < ops.length &&
            ops[i + 1].data == '\n' &&
            (ops[i + 1].attributes == null ||
                ops[i + 1].attributes!.isEmpty)) {
          i++;
        }
      } else {
        pendingOps.add(op);
      }
      i++;
    }
    flushPending();
    return result.toString();
  }
}
