import 'package:flutter/material.dart';
import '../../../core/design/auth_tokens.dart';
import '../../../core/design/native_page_header.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'cancellation_controller.dart';

class CancellationVerificationPage extends StatelessWidget {
  const CancellationVerificationPage({
    required this.state,
    required this.code,
    required this.focusNode,
    required this.onSend,
    required this.onRecover,
    required this.onBack,
    this.maskedPhone,
    super.key,
  });
  final CancellationState state;
  final String? maskedPhone;
  final TextEditingController code;
  final FocusNode focusNode;
  final VoidCallback? onSend, onRecover, onBack;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !state.busy && !state.unknown && state.result == null,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NativePageHeader(title: '输入6位验证码', onBack: onBack),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AuthTokens.horizontalPadding,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AuthTokens.formMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '请验证账号绑定的手机号，验证后仍需确认提交注销申请。',
                          style: AuthTokens.subtitle,
                        ),
                        const SizedBox(height: 4),
                        if (state.delivery != null || maskedPhone != null)
                          Text(
                            '短信验证码已发送至 ${state.delivery?.maskedPhone ?? maskedPhone}',
                            style: AuthTokens.subtitle,
                          ),
                        const SizedBox(height: 28),
                        AuthCodeInput(
                          controller: code,
                          focusNode: focusNode,
                          enabled:
                              !state.busy &&
                              !state.unknown &&
                              state.result == null,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AuthTokens.accent,
                              textStyle: AuthTokens.codeAction,
                            ),
                            onPressed: onSend,
                            child: Text(
                              state.cooldown > 0
                                  ? '${state.cooldown}秒后重新发送'
                                  : '重新发送',
                            ),
                          ),
                        ),
                        if (state.unknown || state.result != null) ...[
                          const SizedBox(height: 20),
                          AuthPrimaryButton(
                            label: state.result != null ? '完成退出登录' : '查询结果',
                            onPressed: onRecover,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
