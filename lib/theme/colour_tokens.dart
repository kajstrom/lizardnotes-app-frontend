import 'package:flutter/material.dart';

abstract final class LnColors {
  // Backgrounds
  static const Color lnBg = Color(0xFF1a1a1a);
  static const Color lnSurface = Color(0xFF222222);
  static const Color lnSurface2 = Color(0xFF2a2a2a);
  static const Color lnSurface3 = Color(0xFF303030);

  // Borders  (semi-transparent)
  static const Color lnBorder = Color(0x14FFFFFF);   // rgba(255,255,255,0.08)
  static const Color lnBorder2 = Color(0x24FFFFFF);  // rgba(255,255,255,0.14)
  static const Color lnBorder3 = Color(0x38FFFFFF);  // rgba(255,255,255,0.22)

  // Text
  static const Color lnText = Color(0xFFe8e6e1);
  static const Color lnText2 = Color(0xFF9a9790);
  static const Color lnText3 = Color(0xFF5e5c58);

  // Accent
  static const Color lnAccent = Color(0xFF7c6fcd);
  static const Color lnAccent2 = Color(0xFFa89de0);
  static const Color lnAccentBg = Color(0x267c6fcd); // rgba(124,111,205,0.15)

  // Danger
  static const Color lnDanger = Color(0xFFc0524a);
  static const Color lnDangerBg = Color(0x1fc0524a); // rgba(192,82,74,0.12)

  // Status
  static const Color lnSuccess = Color(0xFF4a9e6a);
  static const Color lnAmber = Color(0xFFb87c2a);
}
