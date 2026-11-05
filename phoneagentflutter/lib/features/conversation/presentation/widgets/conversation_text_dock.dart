import 'package:flutter/material.dart';
import '../../../../core/design/conversation_tokens.dart';
import 'conversation_text_editor.dart';
import 'native_task_input_corner_icon.dart';
import 'native_task_submit_button.dart';

/// Draft presentation only; enabled gates sending, while editing stays available.
class ConversationTextDock extends StatefulWidget {
  const ConversationTextDock({
    super.key,
    this.compact = false,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    required this.onAttachments,
    required this.onVoice,
    this.onStop,
    this.stopping = false,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend, onVoice;
  final VoidCallback? onAttachments;
  final VoidCallback? onStop;
  final bool stopping;
  @override
  State<ConversationTextDock> createState() => _TextDockState();
}

class _TextDockState extends State<ConversationTextDock> {
  late final _sendEnabled = ValueNotifier(widget.enabled);
  late final _stop = ValueNotifier((
    action: widget.onStop,
    busy: widget.stopping,
  ));
  final _focus = FocusNode();
  ModalRoute<void>? _editorRoute;
  bool _collapsed = false;
  @override
  void didUpdateWidget(covariant ConversationTextDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sendEnabled.value != widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sendEnabled.value = widget.enabled;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stop.value = (action: widget.onStop, busy: widget.stopping);
    });
  }

  @override
  void dispose() {
    final editor = _editorRoute;
    final navigator = editor?.navigator;
    if (editor != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && editor.isActive) navigator.removeRoute(editor);
      });
    }
    _focus.dispose();
    _sendEnabled.dispose();
    _stop.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    final selection = widget.controller.selection;
    _focus.unfocus();
    widget.controller.selection = selection;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (editorContext) {
        _editorRoute = ModalRoute.of<void>(editorContext);
        return ConversationTextEditor(
          controller: widget.controller,
          sendEnabled: _sendEnabled,
          onChanged: widget.onChanged,
          onSend: widget.onSend,
          stop: _stop,
        );
      },
    );
    if (!mounted) return;
    _editorRoute = null;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _collapsed = widget.controller.text.trim().isNotEmpty);
  }

  Widget _button({
    Key? key,
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
  }) => Semantics(
    container: true,
    button: true,
    enabled: onPressed != null,
    label: tooltip,
    onTap: onPressed,
    excludeSemantics: true,
    child: IconButton(
      key: key,
      onPressed: onPressed,
      icon: icon,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
  Widget _send(bool canSend) => SizedBox(
    width: 48,
    height: 48,
    child: Center(
      child: NativeTaskSubmitButton(
        canSend: canSend,
        onSend: widget.onSend,
        onStop: widget.onStop,
        stopping: widget.stopping,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => LayoutBuilder(
          builder: (context, bounds) {
            final painter =
                TextPainter(
                  text: TextSpan(
                    text: value.text.isEmpty ? ' ' : value.text,
                    style: const TextStyle(fontSize: 15, height: 21 / 15),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(
                  maxWidth: (bounds.maxWidth - 152).clamp(1.0, double.infinity),
                );
            final multiline = painter.computeLineMetrics().length > 1;
            painter.dispose();
            final summary = _collapsed && value.text.isNotEmpty;
            final expandedControls = multiline && !summary && !widget.compact;
            final canSend = widget.enabled && value.text.trim().isNotEmpty;
            final input = summary
                ? InkWell(
                    key: const ValueKey('conversation-input-summary'),
                    onTap: () {
                      setState(() => _collapsed = false);
                      _focus.requestFocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                      child: Text(
                        value.text.replaceAll(RegExp(r'\s*\n\s*'), ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  )
                : TextField(
                    key: const ValueKey('conversation-input'),
                    controller: widget.controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: widget.onChanged,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 21 / 15,
                      color: ConversationTokens.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: '输入任务内容',
                      hintStyle: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 14,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                    ),
                  );
            return Container(
              key: const ValueKey('conversation-text-capsule'),
              decoration: BoxDecoration(
                color: ConversationTokens.textSurface,
                border: Border.all(color: ConversationTokens.textBorder),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Stack(
                children: [
                  // Keep EditableText in the same slot across line/IME changes.
                  Padding(
                    padding: expandedControls
                        ? const EdgeInsets.fromLTRB(16, 0, 44, 48)
                        : EdgeInsets.only(
                            left: 44,
                            right: widget.compact && multiline && !summary
                                ? 136
                                : 92,
                          ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: widget.compact
                            ? MediaQuery.textScalerOf(context).scale(21) + 26
                            : double.infinity,
                      ),
                      child: input,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        _button(
                          tooltip: '添加图片',
                          onPressed: widget.onAttachments,
                          icon: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: widget.onAttachments != null
                                ? ConversationTokens.ink
                                : ConversationTokens.inactiveLabel,
                          ),
                        ),
                        const Spacer(),
                        if (widget.compact && multiline && !summary)
                          _button(
                            key: const ValueKey('task-input-expand'),
                            tooltip: '展开输入框',
                            onPressed: _expand,
                            icon: const NativeTaskInputCornerIcon(),
                          ),
                        _button(
                          key: const ValueKey('toggle-voice'),
                          tooltip: '切换到语音输入',
                          onPressed: widget.onVoice,
                          icon: const Icon(
                            Icons.keyboard_voice_rounded,
                            size: 20,
                            color: ConversationTokens.ink,
                          ),
                        ),
                        _send(canSend),
                      ],
                    ),
                  ),
                  if (expandedControls)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _button(
                        key: const ValueKey('task-input-expand'),
                        tooltip: '展开输入框',
                        onPressed: _expand,
                        icon: const NativeTaskInputCornerIcon(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}
