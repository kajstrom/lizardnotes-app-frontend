import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/attachments/models/attachment.dart';
import 'package:lizardnotes_app/features/attachments/providers/attachment_provider.dart';
import 'package:lizardnotes_app/features/attachments/widgets/attachment_chip.dart';

Attachment _meta() => Attachment(
      attachmentId: 'a1',
      noteId: 'n1',
      filename: 'doc.pdf',
      mimeType: 'application/pdf',
      size: 100,
      createdAt: DateTime(2024),
    );

Widget _harness(Widget child) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('uploading state renders percent text and progress bar',
      (tester) async {
    await tester.pumpWidget(_harness(AttachmentChip(
      noteId: 'n1',
      item: AttachmentItem(
        attachment: _meta(),
        status: UploadStatus.uploading,
        progress: 0.42,
      ),
    )));

    expect(find.textContaining('42%'), findsOneWidget);
    // Progress bar is a Positioned 2px Container.
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('complete state renders check icon', (tester) async {
    await tester.pumpWidget(_harness(AttachmentChip(
      noteId: 'n1',
      item: AttachmentItem(
        attachment: _meta(),
        status: UploadStatus.complete,
        progress: 1.0,
      ),
    )));

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('doc.pdf'), findsOneWidget);
  });

  testWidgets('idle state renders filename and paperclip', (tester) async {
    await tester.pumpWidget(_harness(AttachmentChip(
      noteId: 'n1',
      item: AttachmentItem(attachment: _meta()),
    )));

    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.text('doc.pdf'), findsOneWidget);
  });
}
