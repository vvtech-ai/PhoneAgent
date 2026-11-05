import 'package:flutter/material.dart';
import '../../../../core/design/native_dialog_body.dart';

Future<bool?> showAccountEntryConfirmation(
  BuildContext context,
  String phone,
) => showGeneralDialog<bool>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭注销确认',
  barrierColor: const Color(0x700F1218),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220),
  pageBuilder: (_, __, ___) => _AccountEntryConfirmation(phone),
  transitionBuilder: (_, animation, __, child) =>
      FadeTransition(opacity: animation, child: child),
);

class _AccountEntryConfirmation extends StatefulWidget {
  const _AccountEntryConfirmation(this.phone);
  final String phone;
  @override
  State<_AccountEntryConfirmation> createState() =>
      _AccountEntryConfirmationState();
}

class _AccountEntryConfirmationState extends State<_AccountEntryConfirmation> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _closing = false;
  bool _pressed = false;
  bool get _valid =>
      _input.text.trim() == '确认注销' && _input.value.composing.isCollapsed;

  @override
  void initState() {
    super.initState();
    _input.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  void _close(bool confirmed) {
    if (_closing || (confirmed && !_valid)) return;
    _closing = true;
    _focus.unfocus();
    Navigator.of(context).pop(confirmed);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone;
    final masked = phone.length == 11
        ? '${phone.substring(0, 3)}****${phone.substring(7)}'
        : '—';
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: const Color(0x3D0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 322),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  '确认注销账号？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20242B),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              const NativeDialogBody(
                '注销账号后，全部信息将会被移除，且无法找回。若确认注销，请在下方输入框输入“确认注销”。',
                style: TextStyle(
                  fontSize: 14,
                  height: 23.8 / 14,
                  color: Color(0xFF6D747E),
                ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  text: '当前账号  ',
                  children: [
                    TextSpan(
                      text: masked,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3F454E),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8B929C),
                ),
              ),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F4),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: _focus.hasFocus
                        ? const Color(0x1FD74A4A)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Semantics(
                    label: '输入确认注销以继续',
                    child: TextField(
                      key: const Key('account-confirmation-input'),
                      controller: _input,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _focus.unfocus(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF282C34),
                      ),
                      decoration: const InputDecoration(
                        hintText: '确认注销',
                        hintStyle: TextStyle(
                          color: Color(0xFFB2B7BF),
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _button(
                      '取消',
                      const Color(0xFFF0F1F3),
                      const Color(0xFF32363D),
                      () => _close(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => setState(() => _pressed = true),
                      onPointerUp: (_) => setState(() => _pressed = false),
                      onPointerCancel: (_) => setState(() => _pressed = false),
                      child: _button(
                        '注销',
                        _valid
                            ? (_pressed
                                  ? const Color(0xFFCB4040)
                                  : const Color(0xFFE65353))
                            : const Color(0xFFF2F3F4),
                        _valid ? Colors.white : const Color(0xFFF2A8A8),
                        _valid ? () => _close(true) : null,
                        key: const Key('account-entry-confirmation-submit'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    String label,
    Color background,
    Color foreground,
    VoidCallback? onPressed, {
    Key? key,
  }) => TextButton(
    key: key,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledForegroundColor: foreground,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Text(label),
  );
}
