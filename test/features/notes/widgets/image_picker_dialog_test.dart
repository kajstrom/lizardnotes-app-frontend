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
