import 'package:flutter/material.dart';

/// Effective Android/iOS PureVoiceAttachmentSheet shared parameters.
abstract final class AttachmentTokens {
  static const radius = 24.0;
  static const rowRadius = 18.0;
  static const padding = EdgeInsets.fromLTRB(16, 14, 16, 26);
  static const ink = Color(0xFF111827);
  static const secondary = Color(0xFF6B7280);
  static const row = Color(0xFFF8FBFF);
  static const accent = Color(0xFF0A84FF);
  static const iconBackground = Color(0x1F0A84FF);
  static const heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: ink,
  );
  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static const subtitle = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: secondary,
  );
}
