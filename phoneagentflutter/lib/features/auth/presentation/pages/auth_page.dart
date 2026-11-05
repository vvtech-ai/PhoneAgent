import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/auth_tokens.dart';
import '../../../../core/design/native_notice.dart';
import '../../domain/legal_document_port.dart';
import '../controller/auth_controller.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/login_agreement.dart';

class AuthActions {
  const AuthActions({
    required this.phone,
    required this.code,
    required this.invite,
    required this.sendCode,
    required this.submit,
    required this.back,
    this.openDocument,
  });
  final ValueChanged<String> phone, code, invite;
  final VoidCallback sendCode, submit, back;
  final ValueChanged<LegalDocument>? openDocument;
}

/// Pure presentation: text editing/focus are local; requests and decisions are not.
class AuthPage extends StatefulWidget {
  const AuthPage({required this.state, required this.actions, super.key});
  final AuthState state;
  final AuthActions actions;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _invite = TextEditingController();
  final _codeFocus = FocusNode();
  bool _agreementAccepted = false;
  bool _agreementError = false;
  int _agreementFeedback = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
    if (oldWidget.state.busy != AuthBusy.sendingCode &&
        widget.state.busy == AuthBusy.sendingCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.state.invitation ||
            widget.state.busy != AuthBusy.sendingCode ||
            ModalRoute.of(context)?.isCurrent == false) {
          return;
        }
        _codeFocus.requestFocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  void _sync() {
    for (final entry in {
      _phone: widget.state.phone,
      _code: widget.state.code,
      _invite: widget.state.invite,
    }.entries) {
      if (entry.key.text != entry.value) {
        entry.key.value = TextEditingValue(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _invite.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.state.working ||
        (widget.state.invitation && widget.state.invite.trim().isEmpty)) {
      return;
    }
    if (!_requireAgreement()) return;
    FocusScope.of(context).unfocus();
    widget.actions.submit();
  }

  bool _requireAgreement() {
    if (widget.state.invitation || _agreementAccepted) {
      return true;
    }
    setState(() {
      _agreementError = true;
      _agreementFeedback++;
    });
    showNativeNotice(
      context,
      '请先阅读并同意用户协议和隐私政策',
      duration: const Duration(seconds: 2),
    );
    return false;
  }

  void _sendCode() {
    if (widget.state.working || widget.state.visibleRetrySeconds > 0) return;
    if (_requireAgreement()) widget.actions.sendCode();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return PopScope(
      canPop: !state.invitation,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && state.invitation && !state.working) {
          widget.actions.back();
        }
      },
      child: AuthFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrand(),
            const SizedBox(height: AuthTokens.brandGap),
            if (state.invitation) ...[
              AuthInputGroup(
                child: _input(
                  'activationCodeInput',
                  _invite,
                  '请输入邀请码',
                  widget.actions.invite,
                  TextInputType.text,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 10, 2, 18),
                child: Text(
                  '暂无邀请码？请前往官网 CHAKEN.AI 申请。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ] else ...[
              AuthInputGroup(
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Text(
                        '+86',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AuthTokens.foreground,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _input(
                        'loginPhone',
                        _phone,
                        '请输入手机号',
                        (value) {
                          widget.actions.phone(value);
                          // Parent may reject an edit without changing the state value.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _sync();
                          });
                        },
                        AuthTokens.isIOS(context)
                            ? TextInputType.number
                            : TextInputType.phone,
                        next: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuthTokens.fieldGap),
              _codeGroup(),
              ...[
                const SizedBox(height: 15),
                LoginAgreement(
                  accepted: _agreementAccepted,
                  error: _agreementError,
                  feedbackRevision: _agreementFeedback,
                  enabled: !state.working,
                  openDocument: widget.actions.openDocument,
                  onChanged: (value) => setState(() {
                    _agreementAccepted = value;
                    _agreementError = false;
                  }),
                ),
              ],
            ],
            SizedBox(height: state.invitation ? 8 : 16),
            AuthPrimaryButton(
              key: ValueKey(state.invitation ? 'activationBtn' : 'loginBtn'),
              label: state.invitation
                  ? (state.working ? '验证中...' : '确认')
                  : (state.busy == AuthBusy.loggingIn ? '登录中...' : '登录 / 注册'),
              onPressed:
                  state.working ||
                      (state.invitation && state.invite.trim().isEmpty)
                  ? null
                  : _submit,
            ),
            if (state.invitation) ...[
              const SizedBox(height: 24),
              TextButton(
                key: const ValueKey('backLogin'),
                onPressed: state.working ? null : widget.actions.back,
                child: const Text('返回登录'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _input(
    String id,
    TextEditingController controller,
    String hint,
    ValueChanged<String> onChanged,
    TextInputType keyboardType, {
    bool next = false,
  }) => TextField(
    key: ValueKey(id),
    controller: controller,
    focusNode: id == 'loginCode' ? _codeFocus : null,
    enabled:
        !widget.state.working ||
        (id == 'loginCode' && widget.state.busy == AuthBusy.sendingCode),
    keyboardType: keyboardType,
    inputFormatters: id == 'loginCode'
        ? [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ]
        : null,
    textInputAction: next ? TextInputAction.next : TextInputAction.done,
    style: AuthTokens.input,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AuthTokens.input.copyWith(color: AuthTokens.hint),
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    onChanged: onChanged,
    onSubmitted: (_) {
      if (next) {
        _codeFocus.requestFocus();
      } else {
        _submit();
      }
    },
  );

  Widget _codeGroup() {
    final state = widget.state;
    final field = _input(
      'loginCode',
      _code,
      '请输入验证码',
      widget.actions.code,
      TextInputType.number,
    );
    final button = TextButton(
      key: const ValueKey('loginGetCode'),
      style: TextButton.styleFrom(
        textStyle: AuthTokens.codeAction,
        minimumSize: const Size(100, 48),
        foregroundColor: AuthTokens.accent,
        disabledForegroundColor: AuthTokens.hint,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: state.working || state.visibleRetrySeconds > 0
          ? null
          : _sendCode,
      child: Text(
        state.busy == AuthBusy.sendingCode
            ? '发送中...'
            : state.visibleRetrySeconds > 0
            ? '${state.visibleRetrySeconds}s后重试'
            : '获取验证码',
      ),
    );
    return AuthInputGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Accessibility fallback, not a fixed-size design canvas.
          if (constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(12) > 18) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [field, button],
            );
          }
          return Row(
            children: [
              Expanded(child: field),
              button,
            ],
          );
        },
      ),
    );
  }
}
