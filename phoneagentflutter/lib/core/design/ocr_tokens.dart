import 'package:flutter/material.dart';

/// Shared native PureVoiceOcrResultCard / AIPureVoiceOcrResultCardView target.
abstract final class OcrTokens {
  static const cardWidth = 286.0, imageWidth = 210.0, thumb = 60.0;
  static const radius = 18.0, imageRadius = 14.0, fieldRadius = 12.0;
  static const border = Color(0xFFE5EBF3), field = Color(0xFFF8FBFF);
  static const ink = Color(0xFF111827), secondary = Color(0xFF64748B);
  static const bubble = Color(0xFFEAF4FF), accent = Color(0xFF1683FF);
  static const title = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: ink,
  );
  static const summary = TextStyle(fontSize: 12, height: 1.5, color: secondary);
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: secondary,
  );
  static const value = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    color: ink,
  );
  static const body = TextStyle(fontSize: 12, height: 19 / 12, color: ink);
  static const shadow = BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 3),
    blurRadius: 8,
  );
}
