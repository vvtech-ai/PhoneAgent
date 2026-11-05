import 'package:flutter/material.dart';

import '../../../../core/design/auth_tokens.dart';
import '../../domain/legal_document_port.dart';

class LoginAgreement extends StatefulWidget {
  const LoginAgreement({
    required this.accepted,
    required this.error,
    required this.enabled,
    required this.onChanged,
    required this.openDocument,
    this.feedbackRevision = 0,
    super.key,
  });
  final bool accepted, error, enabled;
  final int feedbackRevision;
  final ValueChanged<bool> onChanged;
  final ValueChanged<LegalDocument>? openDocument;
  @override
  State<LoginAgreement> createState() => _LoginAgreementState();
}

class _LoginAgreementState extends State<LoginAgreement>
    with SingleTickerProviderStateMixin {
  static const _error = Color(0xFFE5484D);
  static const _gray = Color(0xFF6B7280);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _offset = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 1),
  ]).animate(_shake);

  @override
  void didUpdateWidget(LoginAgreement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.error || MediaQuery.disableAnimationsOf(context)) {
      _shake.reset();
    } else if (widget.feedbackRevision != oldWidget.feedbackRevision) {
      _shake.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _shake.reset();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _offset,
    builder: (context, child) => Transform.translate(
      key: const ValueKey('loginAgreementFeedback'),
      offset: Offset(_offset.value, 0),
      child: child,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          excludeSemantics: true,
          onTap: widget.enabled
              ? () => widget.onChanged(!widget.accepted)
              : null,
          label: '同意用户协议和隐私政策',
          checked: widget.accepted,
          enabled: widget.enabled,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              key: const ValueKey('loginAgreement'),
              value: widget.accepted,
              activeColor: AuthTokens.accent,
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AuthTokens.accent
                    : Colors.white,
              ),
              side: BorderSide(
                color: widget.accepted
                    ? AuthTokens.accent
                    : widget.error
                    ? _error
                    : const Color(0xFFA8ADB8),
                width: 1.5,
              ),
              onChanged: widget.enabled
                  ? (value) => widget.onChanged(value ?? false)
                  : null,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('我已阅读并同意', style: _textStyle),
              _link('《用户协议》', LegalDocument.userAgreement),
              Text('和', style: _textStyle),
              _link('《隐私政策》', LegalDocument.privacyPolicy),
            ],
          ),
        ),
      ],
    ),
  );

  TextStyle get _textStyle => TextStyle(
    fontSize: 12,
    height: 20 / 12,
    color: widget.error ? _error : _gray,
  );

  Widget _link(String text, LegalDocument document) => TextButton(
    key: ValueKey(document.name),
    style: TextButton.styleFrom(
      foregroundColor: AuthTokens.accent,
      textStyle: const TextStyle(fontSize: 12, height: 20 / 12),
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: widget.openDocument == null
        ? null
        : () => widget.openDocument!(document),
    child: Text(text),
  );
}
