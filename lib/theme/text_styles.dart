import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colour_tokens.dart';

/// Named text styles for every role in the LizardNotes type scale (§3).
///
/// Two families only:
///   Inter 400/500/600/700 — all UI text and note body prose.
///   JetBrains Mono 400/500 — timestamps, filenames, paths, code, labels.
abstract final class LnTextStyles {
  // ── Inter ──────────────────────────────────────────────────────────────────

  /// Note title in editor: 32 px / 600 / lh 1.2 / ls -0.02em
  static TextStyle noteTitle({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.64, // -0.02em × 32
        color: color,
      );

  /// Section header (h2): 22 px / 600 / ls -0.015em
  static TextStyle sectionHeader({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.33, // -0.015em × 22
        color: color,
      );

  /// Sub-header (h3): 17 px / 600 / ls -0.01em
  static TextStyle subHeader({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.17, // -0.01em × 17
        color: color,
      );

  /// Body prose comfortable: 15.5 px / 400 / lh 1.65
  static TextStyle bodyComfortable({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 15.5,
        fontWeight: FontWeight.w400,
        height: 1.65,
        color: color,
      );

  /// Body prose compact: 14 px / 400 / lh 1.55
  static TextStyle bodyCompact({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: color,
      );

  /// Sidebar folder row: 13 px / 400
  static TextStyle sidebarFolder({Color color = LnColors.lnText2}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Note card title: 13 px / 500 / ls -0.005em
  static TextStyle noteCardTitle({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.065, // -0.005em × 13
        color: color,
      );

  /// Note card preview: 12 px / 400 / lh 1.4
  static TextStyle noteCardPreview({Color color = LnColors.lnText2}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// Primary button label: 12 px / 500
  static TextStyle primaryButton({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Modal title: 16 px / 600 / ls -0.01em
  static TextStyle modalTitle({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.16, // -0.01em × 16
        color: color,
      );

  /// Auth card title: 22 px / 600 / ls -0.015em (same metrics as sectionHeader)
  static TextStyle authTitle({Color color = LnColors.lnText}) =>
      GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.33,
        color: color,
      );

  /// Auth card subtitle: 13 px / 400 / lh 1.5
  static TextStyle authSubtitle({Color color = LnColors.lnText2}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  /// Secondary link: 12.5 px / 400
  static TextStyle secondaryLink({Color color = LnColors.lnText2}) =>
      GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // ── JetBrains Mono ─────────────────────────────────────────────────────────

  /// Timestamp / meta: 11 px / 400 / ls 0.03em
  static TextStyle timestamp({Color color = LnColors.lnText3}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.33, // ~0.03em × 11
        color: color,
      );

  /// Uppercase section label: 10 px / 400 / ls 0.08em
  static TextStyle sectionLabel({Color color = LnColors.lnText3}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.8, // 0.08em × 10
        color: color,
      );

  /// Auth field label (uppercase mono): same as sectionLabel.
  static TextStyle authFieldLabel({Color color = LnColors.lnText3}) =>
      sectionLabel(color: color);

  /// Code block: 12.5 px / 400 / lh 1.6
  static TextStyle codeBlock({Color color = LnColors.lnText}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color,
      );

  /// OTP digit: 20 px / 500
  static TextStyle otpDigit({Color color = LnColors.lnText}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: color,
      );
}
