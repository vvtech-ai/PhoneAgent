import 'package:flutter/material.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../../dialer/domain/dial_country.dart';
import '../../../dialer/domain/dial_phone_policy.dart';
import '../../domain/translation_directory.dart';

bool translationPhoneNeedsWarning(
  String raw,
  DialCountry country,
  TranslationDirectoryCountry? configured,
) {
  if (configured == null ||
      configured.phoneRegex.isEmpty ||
      !RegExp(r'^[0-9]+$').hasMatch(raw)) {
    return false;
  }
  final target = DialPhonePolicy.resolve(
    raw,
    country.iso,
    configuredCountry: country,
  );
  return target == null ||
      !configured.acceptsPhone(target.networkNumber ?? target.number);
}

Future<bool> confirmTranslationPhoneFormat(
  BuildContext context, {
  required bool Function() isCurrent,
  required Object Function() readSnapshot,
}) async {
  if (!context.mounted || !isCurrent()) return false;
  final before = readSnapshot();
  final accepted = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (_) => const NativeConfirmationDialog(
      title: '号码格式提醒',
      message: '号码格式可能有误，仍要呼叫吗？',
      confirmLabel: '继续呼叫',
      confirmKey: Key('translation-phone-continue'),
      dismissKey: Key('translation-phone-cancel'),
    ),
  );
  return context.mounted &&
      isCurrent() &&
      accepted == true &&
      before == readSnapshot();
}
