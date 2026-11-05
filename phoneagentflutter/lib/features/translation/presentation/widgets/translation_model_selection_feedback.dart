import 'package:flutter/material.dart';
import '../../../../core/design/native_notice.dart';

/// Successful model changes use the application's shared toast on both platforms.
void showTranslationModelSelectionFeedback(BuildContext context, String name) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  showNativeNotice(context, '翻译通话模型已切换为 $name');
}
