import 'package:flutter/material.dart';

/// Shared native recording metrics, with responsive text and safe touch targets.
/// Runtime visual calibration and actual waveform events remain separate.
abstract final class RecordingTokens {
  static const blue = Color(0xFF1684F8);
  static const radius = 22.0;
  static const outerPadding = EdgeInsets.fromLTRB(20, 8, 20, 16);
  static const minHeight = 81.0;
  static const primarySize = 50.0;
  static const failureMinHeight = 64.0;
  static const failureRadius = 16.0;
  static const failurePadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );
  static const failureTitle = TextStyle(
    fontSize: 12,
    height: 15 / 12,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static const failureSubtitle = TextStyle(
    fontSize: 9,
    height: 12 / 9,
    color: Color(0xE0FFFFFF),
  );
  static const innerPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );
  static const title = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static const subtitle = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    color: Color(0xE0FFFFFF),
  );
  static const notice = TextStyle(fontSize: 12, color: Color(0xFF6E6E73));
}
