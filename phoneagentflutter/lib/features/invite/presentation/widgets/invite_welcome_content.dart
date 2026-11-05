import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_action_style.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/auth_tokens.dart';
import '../controller/invite_welcome_controller.dart';

const _blue = Color(0xFF1985FF);
const _muted = Color(0xFF8E9AB0);

class InviteWelcomeContent extends StatelessWidget {
  const InviteWelcomeContent({
    required this.code,
    required this.state,
    required this.onBack,
    required this.onContinue,
    required this.onRetry,
    super.key,
  });
  final String code;
  final InviteWelcomeState state;
  final VoidCallback onBack, onContinue, onRetry;

  @override
  Widget build(BuildContext context) => NativePageBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final retry = !state.loading && !state.canContinue;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onBack,
                        child: const Text(
                          '‹ 返回',
                          style: TextStyle(color: _blue, fontSize: 13),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: (constraints.maxHeight * .10).clamp(24.0, 88.0),
                    ),
                    const Image(
                      image: AssetImage(AuthTokens.logo),
                      width: 90,
                      height: 88,
                      semanticLabel: 'Phone Agent',
                    ),
                    const SizedBox(height: 16),
                    _label(
                      'Phone Agent',
                      26,
                      const Color(0xFF191E36),
                      weight: FontWeight.w800,
                      spacing: -1,
                    ),
                    const SizedBox(height: 8),
                    _label('电话智能体 - 你的语音分身', 13, _muted),
                    const SizedBox(height: 38),
                    if (state.points != null)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          _label('注册即得', 12, _muted, weight: FontWeight.bold),
                          _label(
                            '${state.points}',
                            34,
                            _blue,
                            weight: FontWeight.w800,
                          ),
                          _label(
                            '积分',
                            17,
                            const Color(0xFF20334F),
                            weight: FontWeight.bold,
                          ),
                        ],
                      )
                    else
                      _label(
                        state.loading ? '正在加载邀请信息…' : state.error,
                        14,
                        _muted,
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 14,
                      children: [
                        _label('邀请码', 12, _muted, weight: FontWeight.bold),
                        _label(
                          code,
                          32,
                          const Color(0xFF203F66),
                          weight: FontWeight.bold,
                          spacing: 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _label('注册时将自动填写', 10, _muted),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: NativeActionSurface(
                        child: FilledButton(
                          key: const ValueKey('inviteWelcomeContinue'),
                          onPressed: state.loading
                              ? null
                              : retry
                              ? onRetry
                              : onContinue,
                          child: Text(retry ? '重新加载' : '立即体验 Phone Agent'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _label(
    String text,
    double size,
    Color color, {
    FontWeight weight = FontWeight.normal,
    double? spacing,
  }) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
    ),
  );
}
