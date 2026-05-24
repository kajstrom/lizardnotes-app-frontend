# Inline Image Insertion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to insert image attachments inline into notes via a format toolbar button, with images stored as `attachment://attachmentId` in markdown and resolved to presigned S3 URLs on note load.

**Architecture:** A custom `ln-image` Quill embed type stores `{attachmentId, url, caption}` in the delta. `ContentPipeline.fromMarkdown` is made async to resolve `attachment://` URIs to presigned URLs on load; `toMarkdown` converts them back. An `ImagePickerDialog` lets users pick existing image attachments or upload new ones; a toolbar button triggers it.

**Tech Stack:** Flutter, flutter_quill ^11.5.0, markdown_quill ^4.3.0, flutter_riverpod 3.x, mocktail (tests), flutter_quill_test (tests)

**Spec:** `docs/superpowers/specs/2026-05-17-inline-image-design.md`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `lib/features/notes/widgets/ln_image_embed.dart` | Quill EmbedBuilder for `ln-image` type |
| Create | `lib/features/notes/widgets/image_picker_dialog.dart` | Modal image picker / uploader |
| Create | `test/features/notes/services/content_pipeline_test.dart` | Unit tests for pipeline changes |
| Create | `test/features/notes/widgets/ln_image_embed_test.dart` | Widget tests for embed |
| Create | `test/features/notes/widgets/image_picker_dialog_test.dart` | Widget tests for picker |
| Modify | `lib/features/notes/services/content_pipeline.dart` | Async fromMarkdown + ln-image toMarkdown |
| Modify | `lib/features/notes/widgets/format_toolbar.dart` | Add noteId param + image button |
| Modify | `lib/features/notes/screens/editor_screen.dart` | Wire embed builder, await fromMarkdown, pass noteId |
| Modify | `test/features/notes/widgets/format_toolbar_test.dart` | Update helpers for new noteId param |

---

## Task 1: ContentPipeline — serialize ln-image in toMarkdown

**Files:**
- Create: `test/features/notes/services/content_pipeline_test.dart`
- Modify: `lib/features/notes/services/content_pipeline.dart`

- [ ] **Step 1.1: Create the test file with three failing tests**

```dart
// test/features/notes/services/content_pipeline_test.dart
import 'package:flutter_quill/flutter_quill.dart';
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

      expect(result, contains('Before'));
      expect(result, contains('![A shot](attachment://img-1)'));
      expect(result, contains('After'));
    });
  });
}
```

- [ ] **Step 1.2: Run the tests — they must FAIL**

```bash
flutter test test/features/notes/services/content_pipeline_test.dart -v
```

Expected: 3 failures — `ContentPipeline.toMarkdown` produces no `attachment://` output.

- [ ] **Step 1.3: Replace `toMarkdown` in `content_pipeline.dart` with the new implementation**

Replace the existing `toMarkdown` method with:

```dart
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
```

- [ ] **Step 1.4: Run the tests — all three must PASS**

```bash
flutter test test/features/notes/services/content_pipeline_test.dart -v
```

Expected: 3 passed.

- [ ] **Step 1.5: Run the full test suite to confirm no regressions**

```bash
flutter test
```

Expected: all existing tests still pass.

- [ ] **Step 1.6: Commit**

```bash
git add lib/features/notes/services/content_pipeline.dart \
        test/features/notes/services/content_pipeline_test.dart
git commit -m "feat: serialize ln-image embeds to attachment:// markdown in toMarkdown"
```

---

## Task 2: ContentPipeline — async fromMarkdown with attachment:// resolution

**Files:**
- Modify: `test/features/notes/services/content_pipeline_test.dart` (add fromMarkdown group)
- Modify: `lib/features/notes/services/content_pipeline.dart`

- [ ] **Step 2.1: Add a `MockApiClient` and four failing tests for `fromMarkdown`**

Add at the top of `content_pipeline_test.dart` (after existing imports):

```dart
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
```

Add inside `void main()`, after the `toMarkdown` group:

```dart
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
```

- [ ] **Step 2.2: Run the new tests — they must FAIL**

```bash
flutter test test/features/notes/services/content_pipeline_test.dart -v
```

Expected: the 4 new `fromMarkdown` tests fail (method signature is still synchronous).

- [ ] **Step 2.3: Replace `fromMarkdown` in `content_pipeline.dart`**

Replace the existing `fromMarkdown` method and `_mdToQuill` field with:

```dart
static final _mdToQuill = MarkdownToDelta(
  markdownDocument: md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ),
);

// Regex matches: ![any caption](attachment://someId)
static final _attachmentRef =
    RegExp(r'!\[([^\]]*)\]\(attachment://([^)]+)\)');

static Future<Document> fromMarkdown(
  String markdown, {
  String? noteId,
  ApiClient? api,
}) async {
  if (markdown.trim().isEmpty) return Document();

  final matches = _attachmentRef.allMatches(markdown).toList();

  // Build a lookup: attachmentId → {caption, resolvedUrl}
  final idToCaption = <String, String>{
    for (final m in matches) m.group(2)!: m.group(1) ?? '',
  };
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
    // We track presignedUrl → attachmentId for the post-processing step.
    final urlToId = <String, String>{};
    String processedMarkdown = markdown;
    for (final entry in idToUrl.entries) {
      final id = entry.key;
      final url = entry.value;
      if (url.isNotEmpty) {
        processedMarkdown = processedMarkdown.replaceAll(
          'attachment://$id',
          url,
        );
        urlToId[url] = id;
      }
    }
    // IDs with no resolved URL keep the attachment:// form in the markdown.
    for (final id in idToCaption.keys) {
      if (!idToUrl.containsKey(id) || idToUrl[id]!.isEmpty) {
        urlToId['attachment://$id'] = id;
      }
    }

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
            processedOps.add(Operation.insert({
              'ln-image': {
                'attachmentId': id,
                'url': idToUrl[id] ?? '',
                'caption': idToCaption[id] ?? '',
              },
            }));
            continue;
          }
        }
      }
      processedOps.add(op);
    }

    return Document.fromDelta(Delta.fromOperations(processedOps));
  } catch (_) {
    return Document()..insert(0, markdown);
  }
}
```

- [ ] **Step 2.4: Run tests — all fromMarkdown + toMarkdown tests must PASS**

```bash
flutter test test/features/notes/services/content_pipeline_test.dart -v
```

Expected: all 7 tests pass.

- [ ] **Step 2.5: Full test suite — no regressions**

```bash
flutter test
```

- [ ] **Step 2.6: Commit**

```bash
git add lib/features/notes/services/content_pipeline.dart \
        test/features/notes/services/content_pipeline_test.dart
git commit -m "feat: make ContentPipeline.fromMarkdown async — resolves attachment:// refs on note load"
```

---

## Task 3: LnImageEmbed widget

**Files:**
- Create: `test/features/notes/widgets/ln_image_embed_test.dart`
- Create: `lib/features/notes/widgets/ln_image_embed.dart`

- [ ] **Step 3.1: Create the failing widget tests**

```dart
// test/features/notes/widgets/ln_image_embed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/widgets/ln_image_embed.dart';
import 'package:lizardnotes_app/theme/colour_tokens.dart';

Widget _buildEditor({
  required Map<String, dynamic> embedData,
  bool readOnly = false,
}) {
  final delta = Delta()
    ..insert({'ln-image': embedData})
    ..insert('\n');
  final controller = QuillController(
    document: Document.fromDelta(delta),
    selection: const TextSelection.collapsed(offset: 0),
  );

  return MaterialApp(
    home: Scaffold(
      body: QuillEditor(
        controller: controller,
        focusNode: FocusNode(),
        scrollController: ScrollController(),
        config: QuillEditorConfig(
          scrollable: true,
          expands: false,
          padding: EdgeInsets.zero,
          readOnly: readOnly,
          embedBuilders: [const LnImageEmbed()],
        ),
      ),
    ),
  );
}

void main() {
  group('LnImageEmbed', () {
    testWidgets('shows broken image placeholder when url is empty',
        (tester) async {
      await tester.pumpWidget(_buildEditor(embedData: {
        'attachmentId': 'abc',
        'url': '',
        'caption': '',
      }));
      await tester.pump();

      expect(find.text('Attachment not found'), findsOneWidget);
    });

    testWidgets('shows caption text in edit mode', (tester) async {
      await tester.pumpWidget(_buildEditor(embedData: {
        'attachmentId': 'abc',
        'url': '',
        'caption': 'My landscape photo',
      }));
      await tester.pump();

      expect(find.text('My landscape photo'), findsOneWidget);
    });

    testWidgets('hides caption input in readOnly mode when caption is empty',
        (tester) async {
      await tester.pumpWidget(_buildEditor(
        embedData: {
          'attachmentId': 'abc',
          'url': '',
          'caption': '',
        },
        readOnly: true,
      ));
      await tester.pump();

      // No TextField for caption, no empty caption text
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField,
        ),
        findsNothing,
      );
    });
  });
}
```

- [ ] **Step 3.2: Run the tests — they must FAIL**

```bash
flutter test test/features/notes/widgets/ln_image_embed_test.dart -v
```

Expected: 3 failures — `LnImageEmbed` does not exist.

- [ ] **Step 3.3: Create `lib/features/notes/widgets/ln_image_embed.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';

/// Custom EmbedBuilder for the 'ln-image' embed type.
///
/// Embed data shape:
///   {'attachmentId': String, 'url': String, 'caption': String}
///
/// 'url' is a presigned S3 URL populated at load time — never persisted.
/// 'caption' round-trips through markdown as the alt-text.
class LnImageEmbed extends EmbedBuilder {
  const LnImageEmbed();

  @override
  String get key => 'ln-image';

  @override
  bool get expanded => true;

  @override
  Widget build(
    BuildContext context,
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final data = Map<String, dynamic>.from(node.value.data as Map);
    return _LnImageEmbedBody(
      data: data,
      controller: controller,
      readOnly: readOnly,
    );
  }
}

class _LnImageEmbedBody extends StatefulWidget {
  const _LnImageEmbedBody({
    required this.data,
    required this.controller,
    required this.readOnly,
  });

  final Map<String, dynamic> data;
  final QuillController controller;
  final bool readOnly;

  @override
  State<_LnImageEmbedBody> createState() => _LnImageEmbedBodyState();
}

class _LnImageEmbedBodyState extends State<_LnImageEmbedBody> {
  late final TextEditingController _captionController;
  Timer? _captionDebounce;

  String get _attachmentId => widget.data['attachmentId'] as String? ?? '';
  String get _url => widget.data['url'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text: widget.data['caption'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _captionDebounce?.cancel();
    _captionController.dispose();
    super.dispose();
  }

  void _onCaptionChanged(String newCaption) {
    _captionDebounce?.cancel();
    _captionDebounce = Timer(const Duration(milliseconds: 300), () {
      _updateEmbedField('caption', newCaption);
    });
  }

  void _updateEmbedField(String field, Object value) {
    final delta = widget.controller.document.toDelta();
    var offset = 0;
    for (final op in delta.toList()) {
      final opData = op.data;
      if (opData is Map && opData.containsKey('ln-image')) {
        final embed = opData['ln-image'] as Map;
        if (embed['attachmentId'] == _attachmentId) {
          final updated = Map<String, dynamic>.from(
            Map<String, dynamic>.from(embed),
          )..[field] = value;
          widget.controller.replaceText(
            offset,
            1,
            BlockEmbed('ln-image', updated),
            null,
          );
          return;
        }
      }
      offset += op.length ?? 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _url.isEmpty
              ? const _BrokenImagePlaceholder()
              : Image.network(
                  _url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 120,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: LnColors.lnAccent,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) =>
                      const _BrokenImagePlaceholder(),
                ),
          const SizedBox(height: 4),
          if (!widget.readOnly)
            TextField(
              controller: _captionController,
              onChanged: _onCaptionChanged,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: LnColors.lnText3,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Add a caption…',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: LnColors.lnText3,
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                isDense: true,
              ),
            )
          else if (_captionController.text.isNotEmpty)
            Text(
              _captionController.text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: LnColors.lnText3,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _BrokenImagePlaceholder extends StatelessWidget {
  const _BrokenImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: LnColors.lnSurface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LnColors.lnBorder2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: LnColors.lnText3,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text('Attachment not found', style: LnTextStyles.timestamp()),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.4: Run tests — all 3 must PASS**

```bash
flutter test test/features/notes/widgets/ln_image_embed_test.dart -v
```

Expected: 3 passed.

- [ ] **Step 3.5: Full test suite**

```bash
flutter test
```

- [ ] **Step 3.6: Commit**

```bash
git add lib/features/notes/widgets/ln_image_embed.dart \
        test/features/notes/widgets/ln_image_embed_test.dart
git commit -m "feat: add LnImageEmbed custom Quill embed widget with caption editing"
```

---

## Task 4: ImagePickerDialog

**Files:**
- Create: `test/features/notes/widgets/image_picker_dialog_test.dart`
- Create: `lib/features/notes/widgets/image_picker_dialog.dart`

- [ ] **Step 4.1: Create failing widget tests**

```dart
// test/features/notes/widgets/image_picker_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/attachments/models/attachment.dart';
import 'package:lizardnotes_app/features/attachments/providers/attachment_provider.dart';
import 'package:lizardnotes_app/features/notes/widgets/image_picker_dialog.dart';

Attachment _attachment(String id, {String mime = 'image/jpeg'}) => Attachment(
      attachmentId: id,
      noteId: 'note-1',
      filename: 'photo_$id.jpg',
      mimeType: mime,
      size: 1024,
      createdAt: DateTime(2024),
    );

AttachmentState _stateWith(List<Attachment> attachments) => AttachmentState(
      items: attachments
          .map((a) => AttachmentItem(attachment: a))
          .toList(),
    );

Widget _wrap(AttachmentState state) {
  return ProviderScope(
    overrides: [
      attachmentProvider('note-1').overrideWith(
        () => _FakeAttachmentNotifier(state),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ImagePickerDialog(noteId: 'note-1'),
      ),
    ),
  );
}

class _FakeAttachmentNotifier
    extends Notifier<AttachmentState>
    implements AttachmentNotifier {
  _FakeAttachmentNotifier(this._state);
  final AttachmentState _state;

  @override
  AttachmentState build() => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ImagePickerDialog', () {
    testWidgets('shows empty state when no image attachments', (tester) async {
      await tester.pumpWidget(_wrap(const AttachmentState()));
      await tester.pump();

      expect(find.text('No images yet'), findsOneWidget);
    });

    testWidgets('shows only image/* attachments', (tester) async {
      final state = _stateWith([
        _attachment('img-1', mime: 'image/jpeg'),
        _attachment('doc-1', mime: 'application/pdf'),
      ]);
      await tester.pumpWidget(_wrap(state));
      await tester.pump();

      expect(find.text('photo_img-1.jpg'), findsOneWidget);
      expect(find.text('photo_doc-1.jpg'), findsNothing);
    });

    testWidgets('tapping an image item pops with the AttachmentItem',
        (tester) async {
      final state = _stateWith([_attachment('img-1')]);
      AttachmentItem? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attachmentProvider('note-1').overrideWith(
              () => _FakeAttachmentNotifier(state),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<AttachmentItem>(
                    context: context,
                    builder: (_) => ImagePickerDialog(noteId: 'note-1'),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('photo_img-1.jpg'));
      await tester.pumpAndSettle();

      expect(result?.attachment.attachmentId, 'img-1');
    });
  });
}
```

- [ ] **Step 4.2: Run the tests — they must FAIL**

```bash
flutter test test/features/notes/widgets/image_picker_dialog_test.dart -v
```

Expected: 3 failures — `ImagePickerDialog` does not exist.

- [ ] **Step 4.3: Create `lib/features/notes/widgets/image_picker_dialog.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';
import '../../attachments/providers/attachment_provider.dart';
import '../../attachments/widgets/upload_overlay.dart';

/// Opens the image picker as a dialog (desktop) or bottom sheet (mobile).
///
/// Returns the selected [AttachmentItem], or null if dismissed.
Future<AttachmentItem?> showImagePickerDialog({
  required BuildContext context,
  required String noteId,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= 600;
  if (isDesktop) {
    return showDialog<AttachmentItem>(
      context: context,
      builder: (_) => _ImagePickerAlertDialog(noteId: noteId),
    );
  }
  return showModalBottomSheet<AttachmentItem>(
    context: context,
    backgroundColor: LnColors.lnSurface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => ImagePickerDialog(noteId: noteId),
  );
}

/// The picker content — use directly inside showModalBottomSheet or wrap in
/// an AlertDialog via [_ImagePickerAlertDialog].
class ImagePickerDialog extends ConsumerWidget {
  const ImagePickerDialog({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attachmentProvider(noteId));
    final imageItems = state.items
        .where((i) => i.attachment.mimeType.startsWith('image/'))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Insert image', style: LnTextStyles.modalTitle()),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    showUploadOverlay(context: context, noteId: noteId),
                icon: const Icon(Icons.upload_outlined,
                    size: 15, color: LnColors.lnAccent2),
                label: Text(
                  'Upload image',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: LnColors.lnAccent2),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageItems.isEmpty)
            const _EmptyState()
          else
            _ImageList(
              items: imageItems,
              onSelected: (item) => Navigator.of(context).pop(item),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                    fontSize: 13, color: LnColors.lnText2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerAlertDialog extends StatelessWidget {
  const _ImagePickerAlertDialog({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LnColors.lnSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LnDims.r10),
        side: const BorderSide(color: LnColors.lnBorder3),
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 440,
        child: ImagePickerDialog(noteId: noteId),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.image_outlined,
              size: 32, color: LnColors.lnText3),
          const SizedBox(height: 8),
          Text('No images yet',
              style: LnTextStyles.bodyComfortable(color: LnColors.lnText2)),
          const SizedBox(height: 4),
          Text('Upload one using the button above.',
              style: LnTextStyles.timestamp()),
        ],
      ),
    );
  }
}

class _ImageList extends StatelessWidget {
  const _ImageList({required this.items, required this.onSelected});

  final List<AttachmentItem> items;
  final void Function(AttachmentItem) onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: LnColors.lnBorder),
        itemBuilder: (_, i) {
          final item = items[i];
          return InkWell(
            onTap: () => onSelected(item),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined,
                      size: 18, color: LnColors.lnText2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.attachment.filename,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: LnColors.lnText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4.4: Run tests — all 3 must PASS**

```bash
flutter test test/features/notes/widgets/image_picker_dialog_test.dart -v
```

- [ ] **Step 4.5: Full test suite**

```bash
flutter test
```

- [ ] **Step 4.6: Commit**

```bash
git add lib/features/notes/widgets/image_picker_dialog.dart \
        test/features/notes/widgets/image_picker_dialog_test.dart
git commit -m "feat: add ImagePickerDialog for selecting and uploading images to insert"
```

---

## Task 5: FormatToolbar — add image button and noteId param

**Files:**
- Modify: `test/features/notes/widgets/format_toolbar_test.dart`
- Modify: `lib/features/notes/widgets/format_toolbar.dart`

- [ ] **Step 5.1: Update `_wrap` and `_wrapWithEditor` helpers in the test file to supply `noteId`**

In `format_toolbar_test.dart`, replace the two helper functions at the top:

```dart
Widget _wrap(QuillController controller, {String noteId = 'note-1'}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 40,
          child: FormatToolbar(controller: controller, noteId: noteId),
        ),
      ),
    ),
  );
}

Widget _wrapWithEditor(QuillController controller, FocusNode editorFocus,
    {String noteId = 'note-1'}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 40,
              child: FormatToolbar(
                controller: controller,
                noteId: noteId,
                editorFocusNode: editorFocus,
              ),
            ),
            Expanded(
              child: QuillEditor.basic(
                controller: controller,
                focusNode: editorFocus,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

Also add a new test case at the end of the `group('FormatToolbar', ...)` block:

```dart
testWidgets('renders image button', (tester) async {
  final controller = QuillController.basic();
  addTearDown(controller.dispose);

  await tester.pumpWidget(_wrap(controller));

  expect(find.byIcon(Icons.image_outlined), findsOneWidget);
});
```

- [ ] **Step 5.2: Run the existing toolbar tests — they fail because `noteId` is now required**

```bash
flutter test test/features/notes/widgets/format_toolbar_test.dart -v
```

Expected: compilation error — `FormatToolbar` does not yet have `noteId`. That's the failing test.

- [ ] **Step 5.3: Add `noteId`, `_ImageToolbarButton`, and the image button wiring to `format_toolbar.dart`**

Add `noteId` to `FormatToolbar`'s constructor:

```dart
class FormatToolbar extends StatefulWidget {
  const FormatToolbar({
    super.key,
    required this.controller,
    required this.noteId,       // ← new required param
    this.scrollable = false,
    this.editorFocusNode,
  });

  final QuillController controller;
  final String noteId;           // ← new field
  final bool scrollable;
  final FocusNode? editorFocusNode;

  @override
  State<FormatToolbar> createState() => _FormatToolbarState();
}
```

Add the import at the top of `format_toolbar.dart`:

```dart
import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import 'image_picker_dialog.dart';
```

Add `_insertImage` and `_openImagePicker` methods to `_FormatToolbarState` (after `_applyLink`):

```dart
Future<void> _openImagePicker() async {
  final selected = await showImagePickerDialog(
    context: context,
    noteId: widget.noteId,
  );
  if (selected == null || !mounted) return;
  await _insertImage(selected);
}

Future<void> _insertImage(AttachmentItem item) async {
  // The picker only surfaces already-uploaded items, but we still need a
  // presigned download URL to populate the embed's url field.
  final api = ref.read(apiClientProvider);
  final url = await api.getAttachmentDownloadUrl(
    noteId: widget.noteId,
    attachmentId: item.attachment.attachmentId,
  );
  final sel = _savedSelection ?? widget.controller.selection;
  final index = sel.isCollapsed ? sel.baseOffset : sel.start;
  final length = sel.isCollapsed ? 0 : sel.end - sel.start;
  widget.controller.replaceText(
    index,
    length,
    BlockEmbed('ln-image', {
      'attachmentId': item.attachment.attachmentId,
      'url': url,
      'caption': '',
    }),
    null,
  );
  widget.editorFocusNode?.requestFocus();
}
```

Add the required imports to `_FormatToolbarState` — `format_toolbar.dart` needs:

```dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';   // ← add
import '../../../api/api_client.dart';                     // ← add
import '../../attachments/providers/attachment_provider.dart'; // ← add (for AttachmentItem type)
```

Change `_FormatToolbarState extends State<FormatToolbar>` to `_FormatToolbarState extends ConsumerState<FormatToolbar>` so Riverpod is available:

```dart
class _FormatToolbarState extends ConsumerState<FormatToolbar> {
```

Add the `_ImageToolbarButton` widget at the bottom of `format_toolbar.dart` (after `_LinkDialog`):

```dart
class _ImageToolbarButton extends StatefulWidget {
  const _ImageToolbarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ImageToolbarButton> createState() => _ImageToolbarButtonState();
}

class _ImageToolbarButtonState extends State<_ImageToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? LnColors.lnSurface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(LnDims.r4),
          ),
          child: const Icon(
            Icons.image_outlined,
            size: 16,
            color: LnColors.lnText2,
          ),
        ),
      ),
    );
  }
}
```

In `_FormatToolbarState.build()`, append `_ImageToolbarButton` after the existing buttons list:

```dart
final buttons = [
  // ... existing buttons unchanged ...
  _ToolbarButton(
    label: 'link',
    isActive: v.linkActive,
    disabled: v.linkDisabled,
    onTap: _applyLink,
  ),
  const _ToolbarDivider(),             // ← new
  _ImageToolbarButton(onTap: _openImagePicker), // ← new
];
```

- [ ] **Step 5.4: Run the toolbar tests — all must PASS including the new image button test**

```bash
flutter test test/features/notes/widgets/format_toolbar_test.dart -v
```

- [ ] **Step 5.5: Full test suite**

```bash
flutter test
```

- [ ] **Step 5.6: Commit**

```bash
git add lib/features/notes/widgets/format_toolbar.dart \
        test/features/notes/widgets/format_toolbar_test.dart
git commit -m "feat: add image button to FormatToolbar — opens image picker to insert inline"
```

---

## Task 6: EditorScreen — wire everything together

**Files:**
- Modify: `lib/features/notes/screens/editor_screen.dart`

No new tests for this task — the integration is verified by running the full suite and manually testing in the browser.

- [ ] **Step 6.1: Add the `LnImageEmbed` import and register it in `QuillEditorConfig`**

Add import at the top of `editor_screen.dart`:

```dart
import '../widgets/ln_image_embed.dart';
```

In `_EditorBody.build()`, add `embedBuilders` to `QuillEditorConfig`:

```dart
config: QuillEditorConfig(
  scrollable: false,
  expands: false,
  padding: EdgeInsets.zero,
  autoFocus: false,
  placeholder: 'Start writing…',
  customStyles: _buildStyles(),
  embedBuilders: [const LnImageEmbed()],   // ← new
  onSingleLongTapEnd: _isMobileWeb
      ? (details, _) { ... }
      : null,
),
```

- [ ] **Step 6.2: Pass `noteId` down to `_DockedFormatBar`**

Add `noteId` to `_DockedFormatBar`:

```dart
class _DockedFormatBar extends StatelessWidget {
  const _DockedFormatBar({
    required this.controller,
    required this.editorFocusNode,
    required this.noteId,        // ← new
    this.scrollable = false,
  });

  final QuillController controller;
  final FocusNode editorFocusNode;
  final String noteId;           // ← new
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: LnColors.lnSurface2,
        border: Border(
          top: BorderSide(color: LnColors.lnBorder, width: 1),
          bottom: BorderSide(color: LnColors.lnBorder, width: 1),
        ),
      ),
      child: FormatToolbar(
        controller: controller,
        noteId: noteId,            // ← new
        scrollable: scrollable,
        editorFocusNode: editorFocusNode,
      ),
    );
  }
}
```

Update both call sites of `_DockedFormatBar` inside `_EditorScreenState.build()` to pass `noteId: _loadedNoteId!`. Both appear inside `if (_loadState == _LoadState.loaded && _loadedNoteId != null)` guards so the `!` is safe:

```dart
// Desktop docked format toolbar
if (isDesktop && _loadState == _LoadState.loaded)
  _DockedFormatBar(
    controller: _quillController,
    editorFocusNode: _editorFocus,
    noteId: _loadedNoteId!,     // ← new
  ),

// Mobile docked format toolbar
if (!isDesktop && _loadState == _LoadState.loaded)
  _DockedFormatBar(
    controller: _quillController,
    editorFocusNode: _editorFocus,
    noteId: _loadedNoteId!,     // ← new
    scrollable: true,
  ),
```

- [ ] **Step 6.3: Await the now-async `ContentPipeline.fromMarkdown` in `_loadNote`**

In `_loadNote`, replace the synchronous call with:

```dart
final doc = await ContentPipeline.fromMarkdown(
  note.content,
  noteId: noteId,
  api: ref.read(apiClientProvider),
);
```

The full updated `_loadNote` try block:

```dart
try {
  final note = await ref.read(apiClientProvider).getNote(noteId);
  unawaited(
    ref.read(attachmentProvider(noteId).notifier).loadAttachments(),
  );
  final doc = await ContentPipeline.fromMarkdown(
    note.content,
    noteId: noteId,
    api: ref.read(apiClientProvider),
  );
  _quillController.document = doc;
  _titleController.text = note.title;
  final count = _countParagraphs(doc);
  if (!mounted) return;
  setState(() {
    _loadState = _LoadState.loaded;
    _noteUpdatedAt = note.updatedAt;
    _paragraphCount = count;
  });
} catch (e) {
  ...
}
```

- [ ] **Step 6.4: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 6.5: Full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6.6: Commit**

```bash
git add lib/features/notes/screens/editor_screen.dart
git commit -m "feat: wire LnImageEmbed into editor — register embed builder, async note load, pass noteId to toolbar"
```

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Storage format `![caption](attachment://id)` | Task 1 (toMarkdown), Task 2 (fromMarkdown) |
| fromMarkdown async, batch-fetch presigned URLs | Task 2 |
| LnImageEmbed full-width + editable caption | Task 3 |
| Broken-image placeholder | Task 3 |
| ImagePickerDialog — filter image/*, empty state, select | Task 4 |
| "Upload image" button in picker | Task 4 |
| FormatToolbar image button | Task 5 |
| EditorScreen: register embed builder, pass noteId | Task 6 |
| toMarkdown pre-processes ln-image embeds | Task 1 |
| Caption round-trips through markdown alt text | Task 1 + Task 2 |

**Type consistency:** `BlockEmbed('ln-image', Map)` is used in Task 3 (`_updateEmbedField`), Task 5 (`_insertImage`). Both use the same key `'ln-image'`. `AttachmentItem` from `attachment_provider.dart` used consistently in Tasks 4 and 5.

**Placeholder scan:** No TBD, no TODO, no "similar to Task N" references. All code is complete.

**Scope:** Six focused tasks, each independently committable.
