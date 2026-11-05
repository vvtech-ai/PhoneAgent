import 'package:flutter/material.dart';
import '../../../../core/design/native_business_dialog.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/shell_tokens.dart';
import 'feedback_form.dart';
import 'feedback_state.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.state,
    required this.onDescription,
    required this.onContact,
    required this.onLogs,
    required this.onAdd,
    required this.onRemove,
    required this.onSubmit,
  });
  final FeedbackState state;
  final ValueChanged<String> onDescription, onContact;
  final ValueChanged<bool> onLogs;
  final VoidCallback onAdd, onSubmit;
  final ValueChanged<int> onRemove;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  bool _discard = false, _asking = false;
  bool get _canPop =>
      _discard ||
      widget.state.success ||
      (!widget.state.hasDraft && !widget.state.busy);
  Future<void> _confirmLeave() async {
    if (_asking || widget.state.busy) return;
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x80000000),
      builder: (context) => NativeBusinessDialog(
        title: '放弃本次反馈？',
        message: '离开后，已填写的内容将不会保留。',
        kind: NativeDialogKind.confirmation,
        danger: true,
        dismissLabel: '继续填写',
        onDismiss: () => Navigator.pop(context, false),
        confirmLabel: '放弃',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    _asking = false;
    if (discard != true || !mounted) return;
    setState(() => _discard = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmLeave();
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      body: NativePageBackground(
        child: SafeArea(
          child: Column(
            children: [
              NativePageHeader(
                title: '问题反馈',
                onBack: widget.state.busy
                    ? null
                    : () => Navigator.maybePop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
                  children: [
                    if (widget.state.success)
                      _success(context)
                    else
                      FeedbackForm(
                        state: widget.state,
                        onDescription: widget.onDescription,
                        onContact: widget.onContact,
                        onLogs: widget.onLogs,
                        onAdd: widget.onAdd,
                        onRemove: widget.onRemove,
                        onSubmit: widget.onSubmit,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _success(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 70, 16, 24),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEFECFF),
          ),
          child: const Icon(Icons.check, size: 32, color: Color(0xFF6C5CE7)),
        ),
        const SizedBox(height: 22),
        const Text(
          '反馈已提交',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text('感谢你的反馈', style: TextStyle(color: Color(0xFF777777))),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShellTokens.accent),
            onPressed: () {
              widget.onSubmit();
              Navigator.maybePop(context);
            },
            child: const Text('完成'),
          ),
        ),
      ],
    ),
  );
}
