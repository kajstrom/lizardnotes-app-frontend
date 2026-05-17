// test/features/notes/widgets/ln_image_embed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/widgets/ln_image_embed.dart';

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
    readOnly: readOnly,
  );

  return MaterialApp(
    home: Scaffold(
      body: QuillEditor(
        controller: controller,
        focusNode: FocusNode(),
        scrollController: ScrollController(),
        config: const QuillEditorConfig(
          scrollable: true,
          expands: false,
          padding: EdgeInsets.zero,
          embedBuilders: [LnImageEmbed()],
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
