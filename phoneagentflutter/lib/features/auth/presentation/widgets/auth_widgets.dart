import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/auth_tokens.dart';
import '../../../../core/design/native_action_style.dart';
import '../../../../core/design/native_page_background.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
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
  const AuthInputGroup({
    required this.child,
    this.focused,
    this.backgroundColor = AuthTokens.field,
    this.borderColor = Colors.transparent,
    super.key,
  });
  final Widget child;
  final bool? focused;
  final Color backgroundColor, borderColor;
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
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(AuthTokens.radius),
        border: Border.all(
          color: (widget.focused ?? _focused)
              ? AuthTokens.accent
              : widget.borderColor,
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
    child: DecoratedBox(
      decoration: NativeActionStyle.decoration(enabled: onPressed != null),
      child: FilledButton(
        style: NativeActionStyle.buttonStyle(context),
        onPressed: onPressed,
        child: Text(label, textAlign: TextAlign.center),
      ),
    ),
  );
}

/// One input owns paste/autofill; six existing-style surfaces render its digits.
class AuthCodeInput extends StatelessWidget {
  const AuthCodeInput({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: AuthTokens.fieldHeight,
    child: Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: '6位验证码',
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                key: const Key('verification-code-input'),
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                enabled: enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: onChanged,
                style: AuthTokens.input,
                showCursor: false,
                decoration: null,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  controller,
                  if (focusNode != null) focusNode!,
                ]),
                builder: (_, __) => Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AuthInputGroup(
                          focused: focusNode == null ? null : _active(i),
                          backgroundColor: AuthTokens.codeField,
                          borderColor: AuthTokens.codeBorder,
                          child: Center(
                            child: _active(i) && controller.text.length <= i
                                ? const SizedBox(
                                    height: 20,
                                    child: VerticalDivider(
                                      width: 2,
                                      thickness: 2,
                                      color: AuthTokens.foreground,
                                    ),
                                  )
                                : Text(
                                    controller.text.length > i
                                        ? controller.text[i]
                                        : '',
                                    style: AuthTokens.input,
                                  ),
                          ),
                        ),
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
  );

  bool _active(int index) =>
      enabled &&
      focusNode?.hasFocus == true &&
      index == controller.text.length.clamp(0, 5);
}
