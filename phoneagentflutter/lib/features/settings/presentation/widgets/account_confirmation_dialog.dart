import 'package:flutter/material.dart';
export 'account_entry_confirmation_dialog.dart'
    show showAccountEntryConfirmation;
import '../../../../core/design/native_business_dialog.dart';
import '../../../../core/design/native_dialog_body.dart';
import '../../../../core/design/auth_tokens.dart';
import '../../../account_cancellation/domain/account_cancellation.dart';

Future<bool?> showAccountConfirmation(
  BuildContext context,
  String phone, {
  required CancellationConfirmation confirmation,
  required Future<void> Function() openAgreement,
}) => showDialog<bool>(
  context: context,
  barrierLabel: '关闭注销确认',
  builder: (dialogContext) => NativeBusinessDialog(
    title: '注销账号',
    kind: NativeDialogKind.confirmation,
    danger: true,
    content: NativeDialogBody(
      '点击注销后，账号将在 ${cancellationTime(confirmation.estimatedEffectiveAt)} 完成注销。'
      '期间若再次登录，注销流程将自动终止。\n'
      '继续注销，即视为你已阅读并同意《PhoneAgent 账号注销协议》。',
      builder: (_, alignment) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '点击注销后，账号将在 ${cancellationTime(confirmation.estimatedEffectiveAt)} 完成注销。'
            '期间若再次登录，注销流程将自动终止。',
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: alignment == TextAlign.center
                ? WrapAlignment.center
                : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('继续注销，即视为你已阅读并同意'),
              TextButton(
                key: const Key('account-cancellation-agreement'),
                style: TextButton.styleFrom(
                  foregroundColor: AuthTokens.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: openAgreement,
                child: const Text('《PhoneAgent 账号注销协议》'),
              ),
              const Text('。'),
            ],
          ),
        ],
      ),
    ),
    dismissLabel: '取消',
    onDismiss: () => Navigator.pop(dialogContext, false),
    confirmLabel: '注销',
    confirmKey: const Key('account-confirmation-submit'),
    onConfirm: () => Navigator.pop(dialogContext, true),
  ),
);
