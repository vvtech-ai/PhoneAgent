import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Android international keypad feedback; no session/business effect.
void androidTranslationDtmfInputFeedback() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
}
