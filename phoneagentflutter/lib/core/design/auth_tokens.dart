import 'package:flutter/material.dart';

/// Native V88AuthPages / AILoginViewController presentation parameters.
abstract final class AuthTokens {
  static const accent = Color(0xFF0A84FF);
  static const foreground = Color(0xFF1A1A2E);
  static const secondary = Color(0xFF8B8FA3);
  static const hint = Color(0xFFB0B4C3);
  static const field = Color(0xFFF5F7FA);
  static const radius = 12.0;
  static const horizontalPadding = 24.0;
  static const formMaxWidth = 320.0;
  static const fieldHeight = 48.0;
  static const ctaHeight = 50.0;
  static const fieldGap = 12.0;
  static const ctaGap = 20.0;
  static const brandGap = 40.0;
  static bool isIOS(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;
  static const brandName = 'PhoneAgent';
  static const background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFEFEFE), Color(0xFFFAFBFD)],
  );
  static const logo = 'assets/images/auth_brand_logo.png';
  static const title = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    color: foreground,
  );
  static const subtitle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    color: secondary,
  );
  static const input = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    color: foreground,
  );
  static const cta = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
  );
  static const codeAction = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );
}
