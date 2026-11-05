import 'package:flutter/material.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../domain/cross_border_translation_call.dart';

Future<bool> confirmCrossBorderTranslationCall(
  BuildContext context, {
  required String? callerCountryIso,
  required String? calleeCountryIso,
  required bool Function() isCurrent,
  required Object Function() readSnapshot,
}) async {
  if (!context.mounted || !isCurrent()) return false;
  if (!shouldConfirmCrossBorderTranslationCall(
    translationEnabled: true,
    callerCountryIso: callerCountryIso,
    calleeCountryIso: calleeCountryIso,
  )) {
    return true;
  }
  final before = readSnapshot();
  final accepted = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (_) => const NativeConfirmationDialog(
      title: '跨境通话质量提示',
      message: '当前为跨境实时翻译通话，可能出现信号不稳定或延迟较大的情况。',
      dismissLabel: '取消',
      confirmLabel: '仍要继续',
      confirmKey: Key('cross-border-continue'),
      dismissKey: Key('cross-border-cancel'),
    ),
  );
  return context.mounted &&
      isCurrent() &&
      accepted == true &&
      before == readSnapshot();
}
