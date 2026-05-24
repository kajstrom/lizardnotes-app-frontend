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
    EmbedContext embedContext,
  ) {
    final data = Map<String, dynamic>.from(
      embedContext.node.value.data as Map,
    );
    return _LnImageEmbedBody(
      data: data,
      controller: embedContext.controller,
      readOnly: embedContext.readOnly,
      nodeOffset: embedContext.node.documentOffset,
    );
  }
}

class _LnImageEmbedBody extends StatefulWidget {
  const _LnImageEmbedBody({
    required this.data,
    required this.controller,
    required this.readOnly,
    required this.nodeOffset,
  });

  final Map<String, dynamic> data;
  final QuillController controller;
  final bool readOnly;
  final int nodeOffset;

  @override
  State<_LnImageEmbedBody> createState() => _LnImageEmbedBodyState();
}

class _LnImageEmbedBodyState extends State<_LnImageEmbedBody> {
  late final TextEditingController _captionController;
  Timer? _captionDebounce;
  late int _nodeOffset;

  String get _url => widget.data['url'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _nodeOffset = widget.nodeOffset;
    _captionController = TextEditingController(
      text: widget.data['caption'] as String? ?? '',
    );
  }

  @override
  void didUpdateWidget(_LnImageEmbedBody old) {
    super.didUpdateWidget(old);
    _nodeOffset = widget.nodeOffset;
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
    final ops = widget.controller.document.toDelta().toList();
    var offset = 0;
    for (final op in ops) {
      if (offset == _nodeOffset) {
        final opData = op.data;
        if (opData is Map && opData.containsKey('ln-image')) {
          final embed = opData['ln-image'] as Map;
          final updated = Map<String, dynamic>.from(
            Map<String, dynamic>.from(embed),
          )..[field] = value;
          widget.controller.replaceText(
            _nodeOffset,
            1,
            Embeddable('ln-image', updated),
            null,
          );
        }
        return;
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
                  errorBuilder: (context, error, stackTrace) =>
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
