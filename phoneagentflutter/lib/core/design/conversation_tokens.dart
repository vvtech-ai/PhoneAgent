import 'package:flutter/material.dart';

/// Shared effective native conversation presentation parameters.
abstract final class ConversationTokens {
  static const accent = Color(0xFF0A84FF);
  static const title = Color(0xFF1A1A1A);
  static const subtitle = Color(0xFF8F98A8);
  static const inactiveLabel = Color(0xFF8F98A8);
  static const stageCurrentLabel = Color(0xFF007AFF);
  static const stageCompletedLabel = Color(0xFF34C759);
  static const inactiveBar = Color(0xFFDDE4EF);
  static const model = Color(0xFF5F6B7A);
  static const ink = Color(0xFF0F172A);
  static const sideButton = 40.0;
  static const voiceButton = 56.0;
  static const controlSlot = 72.0;
  static const motionDuration = Duration(milliseconds: 180);
  static const textSurface = Color(0xFFF3F6FB);
  static const textBorder = Color(0xE6E2E8F0);
  static const actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
  );
  static const completedStageGradient = LinearGradient(
    colors: [Color(0xFF30D158), stageCompletedLabel],
  );
  static const stageGradient = LinearGradient(
    colors: [accent, Color(0xFF49A4FF)],
  );
}
