import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_gradient_action.dart';
import '../controller/outbound_number_controller.dart';

/// Same editable form for the real account repository and isolated previews.
class OutboundNumberPage extends StatefulWidget {
  const OutboundNumberPage({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onLoad,
    required this.onSave,
    required this.onDelete,
    this.preview = false,
  });
  final OutboundNumberState state;
  final ValueChanged<String> onEdit;
  final Future<bool> Function() onLoad, onSave, onDelete;
  final bool preview;
  @override
  State<OutboundNumberPage> createState() => _OutboundNumberPageState();
}

class _OutboundNumberPageState extends State<OutboundNumberPage> {
  late final _input = TextEditingController(text: widget.state.draft);
  @override
  void didUpdateWidget(OutboundNumberPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state.saved, widget.state.saved)) {
      _input.value = TextEditingValue(
        text: widget.state.draft,
        selection: TextSelection.collapsed(offset: widget.state.draft.length),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool _finished = false, _writing = false;
  bool get _current =>
      mounted && !_finished && ModalRoute.of(context)?.isCurrent == true;
  bool get _editable => _current && !_writing && !widget.state.busy;

  void _back() {
    if (!_current || !Navigator.canPop(context)) return;
    _finished = true;
    Navigator.pop(context);
  }

  Future<void> _write(Future<bool> Function() action, String message) async {
    if (!_editable) return;
    _writing = true;
    try {
      final success = await action();
      if (!mounted || !_current || !success) return;
      _finished = true;
      Navigator.pop(context, message);
    } finally {
      _writing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0x143C3C43)),
    );
    const statusStyle = TextStyle(
      fontSize: 12,
      height: 14 / 12,
      letterSpacing: 0,
      color: Color(0xFF6E6E73),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            NativePageHeader(title: '固定外呼号码', onBack: _back),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                children: [
                  if (widget.preview)
                    const Text('MOCK · 内存配置，不修改真实外呼号码；使用合成号码演练。'),
                  const Text(
                    '手机号码',
                    style: TextStyle(
                      fontSize: 12,
                      height: 14 / 12,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E6E73),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: '手机号码',
                    child: TextField(
                      key: const Key('outbound-number-input'),
                      controller: _input,
                      enabled: !state.busy,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 18 / 15,
                        letterSpacing: 0,
                        color: Color(0xFF111111),
                      ),
                      decoration: InputDecoration(
                        constraints: const BoxConstraints(minHeight: 48),
                        hintText: '例如：13800138000',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          height: 18 / 14,
                          letterSpacing: 0,
                          color: Color(0xFF98A2B3),
                        ),
                        filled: true,
                        fillColor: const Color(0xF0FFFFFF),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder,
                        disabledBorder: inputBorder,
                      ),
                      onChanged: (value) {
                        if (_editable) widget.onEdit(value);
                      },
                    ),
                  ),
                  if (state.operation == OutboundOperation.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('正在读取当前固定外呼号码...', style: statusStyle),
                    ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          state.error!,
                          style: statusStyle.copyWith(
                            color: const Color(0xFFE14D46),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  NativeGradientAction(
                    onPressed: state.busy
                        ? null
                        : () => _write(widget.onSave, '固定外呼号码已保存'),
                    label: state.operation == OutboundOperation.saving
                        ? '保存中...'
                        : '保存',
                  ),
                  if (state.saved?.number.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: NativeGradientAction(
                        tone: NativeActionTone.danger,
                        onPressed: state.busy
                            ? null
                            : () => _write(widget.onDelete, '固定外呼号码已删除'),
                        label: state.operation == OutboundOperation.deleting
                            ? '删除中...'
                            : '删除固定外呼号码',
                      ),
                    ),
                  if (state.error != null)
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : () {
                              if (_editable) widget.onLoad();
                            },
                      child: const Text('重新读取'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
