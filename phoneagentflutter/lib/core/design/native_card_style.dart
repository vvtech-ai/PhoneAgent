import 'package:flutter/material.dart';

/// D05 ordinary information surface; specialized controls keep their own style.
abstract final class NativeCardStyle {
  static const decoration = BoxDecoration(
    color: Color(0xCCFFFFFF),
    borderRadius: BorderRadius.all(Radius.circular(24)),
    border: Border.fromBorderSide(BorderSide(color: Color(0xC7FFFFFF))),
    boxShadow: [
      BoxShadow(color: Color(0x14101114), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );
}
