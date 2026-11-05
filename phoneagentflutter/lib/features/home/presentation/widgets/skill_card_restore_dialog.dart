import 'package:flutter/material.dart';
import '../../../../core/design/native_confirmation_dialog.dart';

Future<bool> confirmSkillCardRestore(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const NativeConfirmationDialog(
        title: '恢复默认设置？',
        message: '将清除当前账号的卡片顺序和显示设置。',
        confirmLabel: '恢复默认',
        confirmKey: Key('skill-restore-confirm'),
      ),
    ) ??
    false;
