import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';

/// A row of six single-digit text fields for OTP / TOTP entry.
///
/// Spec (§7.4):
///   42 × 50 px boxes, 8 px gap, JetBrains Mono 20 px / 500.
///   Focused or filled: border lnAccent; filled value: text lnAccent2.
///
/// Behaviour:
///   - Typing a digit auto-advances focus to the next field.
///   - Backspace on an empty field moves focus to the previous field.
///   - When all six digits are filled [onComplete] fires with the 6-digit string.
class OtpInputRow extends StatefulWidget {
  const OtpInputRow({super.key, required this.onComplete});

  final void Function(String code) onComplete;

  @override
  State<OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<OtpInputRow> {
  static const _length = 6;

  final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_length, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Rebuild when any cell value changes so filled-text color updates.
    for (final c in _controllers) {
      c.addListener(() => setState(() {}));
    }
    for (var i = 0; i < _length; i++) {
      final index = i;
      _focusNodes[index].onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[index].text.isEmpty &&
            index > 0) {
          _controllers[index - 1].clear();
          _focusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          Clipboard.getData(Clipboard.kTextPlain).then((data) {
            if (data?.text != null) _distributeDigits(data!.text!);
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _distributeDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (var i = 0; i < _length && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    final next = (digits.length - 1).clamp(0, _length - 1);
    _focusNodes[next].requestFocus();
    _maybeComplete();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _distributeDigits(value);
      return;
    }

    if (value.isEmpty) {
      // Backspace on a filled field — stay or move left.
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return;
    }

    // Single digit entered — advance focus.
    if (index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    _maybeComplete();
  }

  void _maybeComplete() {
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      widget.onComplete(_controllers.map((c) => c.text).join());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _length; i++) ...[
            _buildCell(i),
            if (i < _length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(int index) {
    final isFilled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 42,
      height: 50,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: LnTextStyles.otpDigit(
          color: isFilled ? LnColors.lnAccent2 : LnColors.lnText,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: LnColors.lnSurface2,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LnDims.r6),
            borderSide: const BorderSide(color: LnColors.lnBorder2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LnDims.r6),
            borderSide: BorderSide(
              color: isFilled ? LnColors.lnAccent : LnColors.lnBorder2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LnDims.r6),
            borderSide: const BorderSide(color: LnColors.lnAccent),
          ),
        ),
        onChanged: (v) => _onChanged(index, v),
      ),
    );
  }
}
