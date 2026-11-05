import 'package:flutter/material.dart';
import '../../../../core/design/native_business_dialog.dart';

Future<void> showLogoutConfirmation(
  BuildContext context,
  Future<void> Function() signOut,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: const Color(0x80000000),
  builder: (_) => _LogoutDialog(signOut),
);

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog(this.signOut);
  final Future<void> Function() signOut;
  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _busy = false;
  bool _finished = false;
  String _error = '';
  bool get _current =>
      mounted && !_finished && ModalRoute.of(context)?.isCurrent == true;

  void _close() {
    if (!_current) return;
    _finished = true;
    Navigator.pop(context);
  }

  void _cancel() {
    if (_busy) return;
    _close();
  }

  Future<void> _confirm() async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.signOut();
      _close();
    } catch (_) {
      if (mounted && !_finished) {
        setState(() {
          _busy = false;
          _error = '退出失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => NativeBusinessDialog(
    title: '退出登录？',
    message: '退出后将回到手机号登录页，当前账号数据仍会保留。',
    error: _error,
    kind: NativeDialogKind.confirmation,
    danger: true,
    allowBack: !_busy,
    dismissLabel: '取消',
    dismissKey: const ValueKey('logout-cancel'),
    onDismiss: _busy ? null : _cancel,
    confirmKey: const ValueKey('logout-confirm'),
    confirmLabel: _busy ? '退出中…' : '退出',
    onConfirm: _busy ? null : _confirm,
  );
}
