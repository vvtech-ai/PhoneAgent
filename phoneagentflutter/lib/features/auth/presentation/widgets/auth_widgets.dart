import 'package:flutter/material.dart';

import '../../../../core/design/auth_tokens.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: AuthTokens.background),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuthTokens.horizontalPadding,
                    24,
                    AuthTokens.horizontalPadding,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AuthTokens.formMaxWidth,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Image(
        image: AssetImage(AuthTokens.logo),
        width: 107,
        height: 98,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
      const SizedBox(height: 14),
      Text(
        AuthTokens.brandName,
        style: AuthTokens.title,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      const Text(
        '电话智能体 - 你的语音分身',
        style: AuthTokens.subtitle,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class AuthInputGroup extends StatefulWidget {
  const AuthInputGroup({required this.child, super.key});
  final Widget child;
  @override
  State<AuthInputGroup> createState() => _AuthInputGroupState();
}

class _AuthInputGroupState extends State<AuthInputGroup> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (value) => setState(() => _focused = value),
    child: Container(
      constraints: const BoxConstraints(minHeight: AuthTokens.fieldHeight),
      decoration: BoxDecoration(
        color: AuthTokens.field,
        borderRadius: BorderRadius.circular(AuthTokens.radius),
        border: Border.all(
          color: _focused ? AuthTokens.accent : Colors.transparent,
        ),
      ),
      child: widget.child,
    ),
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AuthTokens.ctaHeight),
        padding: const EdgeInsets.symmetric(vertical: 13),
        backgroundColor: AuthTokens.accent,
        disabledBackgroundColor: AuthTokens.accent.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        textStyle: AuthTokens.cta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuthTokens.radius),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}
