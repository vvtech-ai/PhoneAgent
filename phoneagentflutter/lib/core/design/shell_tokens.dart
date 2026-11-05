import 'package:flutter/material.dart';

/// Shared native home/card/navigation parameters; page titles remain scoped.
abstract final class ShellTokens {
  static const background = Color(0xFFFBFCFD);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF6E6E73);
  static const accent = Color(0xFF0A84FF);
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: ink,
    height: 1.12,
  );
  static TextStyle homeTitle(BuildContext context) => title.copyWith(
    fontSize: 31,
    height: 32 / 31,
    fontWeight: FontWeight.w800,
  );
  static const subtitle = TextStyle(fontSize: 13, color: muted, height: 1.5);
  static const section = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: ink,
  );
  static const cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.1,
  );
  static const cardSubtitle = TextStyle(
    fontSize: 13,
    color: muted,
    height: 1.5,
  );
  static const cardRadius = 24.0, gridGap = 12.0, navHeight = 74.0;
  static const softShadow = BoxShadow(
    color: Color(0x14101114),
    blurRadius: 24,
    offset: Offset(0, 10),
  );
  static const cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
    boxShadow: [softShadow],
  );
}
