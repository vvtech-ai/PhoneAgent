import 'package:flutter/material.dart';
import '../../../../core/design/native_confirmation_dialog.dart';

Future<bool> confirmMemoryDeletion(
  BuildContext context, {
  required bool all,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => NativeConfirmationDialog(
        title: all ? '删除全部记忆？' : '删除这条记忆？',
        message: all ? '列表中的记忆将全部删除，删除后无法恢复。' : '删除后，AI 将不再使用这条记忆。',
        confirmLabel: '确认删除',
        danger: true,
      ),
    ) ??
    false;
