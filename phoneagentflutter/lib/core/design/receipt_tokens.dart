import 'package:flutter/material.dart';

/// Static pv-summary-card CSS (0cd58de) and v65 BatchPlus/LargeTaskCardShell.
abstract final class ReceiptTokens {
  static const singleWidth = 280.0, batchWidth = 308.0;
  static const radius = 16.0, itemRadius = 12.0, progressHeight = 7.0;
  static const blue = Color(0xFF007AFF), green = Color(0xFF34C759);
  static const text = Color(0xFF202938), secondary = Color(0xFF596579);
  static const border = Color(0xFFE4E9F0), muted = Color(0xFFF5F7FA);
  static const title = TextStyle(
    fontSize: 14,
    height: 19 / 14,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(fontSize: 12, height: 16 / 12, color: text);
  static const caption = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    color: secondary,
  );
  static const success = [Color(0xFFEDFAF0), Color(0xFFD6F5DC)];
  static const unclear = [Color(0xFFFFF8E1), Color(0xFFFFE8A3)];
  static const failure = [Color(0xFFFFF1F0), Color(0xFFFFDAD6)];
}
