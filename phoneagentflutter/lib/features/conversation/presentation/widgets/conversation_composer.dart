import 'package:flutter/material.dart';
import '../../../../core/design/ai_content_notice.dart';
import '../../../../core/design/conversation_tokens.dart';
import 'voice_composer_binding.dart';
import 'native_keyboard_mode_icon.dart';
import 'voice_hold_button.dart';
import 'native_conversation_model_selector.dart';
import 'conversation_text_dock.dart';
import 'conversation_ai_content_notice.dart';
import 'native_task_submit_button.dart';
import 'speech_stop_hold_control.dart';
import '../controller/task_draft_controller.dart';
import '../../domain/drafts/task_draft.dart';

class ConversationComposer extends StatefulWidget {
  const ConversationComposer({
    super.key,
    this.compact = false,
    required this.voiceMode,
    required this.canSend,
    required this.modelName,
    required this.onToggle,
    required this.onSend,
    required this.onNotice,
    required this.onModels,
    this.onAttachments,
    this.voice,
    this.draft,
    this.onStop,
    this.stopping = false,
    this.inputBlocked = false,
    this.auxiliaryEnabled = true,
  });
  final bool voiceMode, canSend;
  final bool compact;
  final String modelName;
  final VoidCallback onToggle, onModels;
  final VoidCallback? onAttachments;
  final bool Function(String) onSend;
  final ValueChanged<String> onNotice;
  final VoiceComposerBinding? voice;
  final TaskDraftController? draft;
  final VoidCallback? onStop;
  final bool stopping;
  final bool inputBlocked;
  final bool auxiliaryEnabled;
  @override
  State<ConversationComposer> createState() => _ComposerState();
}

class _ComposerState extends State<ConversationComposer> {
  final _input = TextEditingController();
  bool _speechHold = false;
  bool get _canChangeContext =>
      widget.auxiliaryEnabled &&
      widget.canSend &&
      !widget.inputBlocked &&
      !widget.stopping &&
      widget.onStop == null &&
      !_speechHold &&
      (widget.voice?.state.canPress ?? true);

  VoidCallback? get _attachments => _canChangeContext
      ? widget.onAttachments ?? () => widget.onNotice('此演练未接附件端口')
      : null;
  @override
  void initState() {
    super.initState();
    widget.draft?.addListener(_restoreDraft);
    _restoreDraft();
  }

  @override
  void didUpdateWidget(ConversationComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft?.removeListener(_restoreDraft);
      widget.draft?.addListener(_restoreDraft);
      _restoreDraft();
    }
  }

  void _restoreDraft() {
    final draft = widget.draft;
    if (draft == null || !mounted) return;
    final value = draft.value;
    _input.value = TextEditingValue(
      text: value.text,
      selection: TextSelection(
        baseOffset: value.start.clamp(0, value.text.length),
        extentOffset: value.end.clamp(0, value.text.length),
      ),
    );
    setState(() {});
  }

  @override
  void dispose() {
    widget.draft?.removeListener(_restoreDraft);
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final accepted =
        widget.canSend &&
        (widget.draft?.submit(widget.onSend) ?? widget.onSend(_input.text));
    if (accepted) {
      _input.clear();
      FocusScope.of(context).unfocus();
      setState(() {});
    }
  }

  Widget _sideButton({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    required Widget icon,
  }) => SizedBox(
    width: 48,
    height: 48,
    child: Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: IconButton(
        key: key,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: icon,
      ),
    ),
  );

  void _toggle() {
    FocusScope.of(context).unfocus();
    widget.onToggle();
  }

  Widget _controls() => widget.voiceMode
      ? SizedBox(
          width: double.infinity,
          height: ConversationTokens.controlSlot,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 14,
                child: _sideButton(
                  label: '添加图片',
                  onTap: _attachments,
                  icon: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: _canChangeContext
                        ? ConversationTokens.ink
                        : ConversationTokens.inactiveLabel,
                  ),
                ),
              ),
              if (!widget.stopping &&
                  (widget.voice?.canInterruptReply == true || _speechHold))
                SpeechStopHoldControl(
                  binding: widget.voice,
                  canStart:
                      !widget.inputBlocked &&
                      widget.canSend &&
                      widget.onStop == null &&
                      !widget.stopping,
                  onHoldChanged: (value) {
                    if (mounted) setState(() => _speechHold = value);
                  },
                  onStop: widget.onStop,
                )
              else if (widget.onStop != null || widget.stopping)
                NativeTaskSubmitButton(
                  voiceControl: true,
                  canSend: false,
                  onSend: () {},
                  onStop: widget.onStop,
                  stopping: widget.stopping,
                )
              else
                VoiceHoldButton(
                  binding: widget.voice,
                  enabled: !widget.inputBlocked && widget.canSend,
                  icon: const Icon(
                    Icons.keyboard_voice_rounded,
                    size: 25,
                    color: Colors.white,
                  ),
                  onUnavailable: () => widget.onNotice('此演练未接语音端口，请切换文字输入'),
                ),
              Positioned(
                right: 16,
                child: _sideButton(
                  key: const ValueKey('toggle-text'),
                  label: '切换到文字输入',
                  onTap: _toggle,
                  icon: const NativeKeyboardModeIcon(),
                ),
              ),
            ],
          ),
        )
      : ConversationTextDock(
          compact: widget.compact,
          controller: _input,
          enabled: widget.canSend,
          onChanged: (_) {
            widget.draft?.edit(
              TaskDraft(
                _input.text,
                start: _input.selection.baseOffset,
                end: _input.selection.extentOffset,
              ),
            );
            setState(() {});
          },
          onSend: _send,
          onStop: !widget.stopping && widget.voice?.canInterruptReply == true
              ? widget.voice?.onStopSpeech ?? widget.onStop
              : widget.onStop,
          stopping: widget.stopping,
          onAttachments: _attachments,
          onVoice: _toggle,
        );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final noticeAdjustment = AiContentNotice.iosSafeAreaAdjustment(context);
    // Scaffold removes consumed viewInsets from its body after resizing. Read
    // the owning view only to detect the keyboard, never to add its height again.
    final keyboardVisible =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        View.of(context).viewInsets.bottom > 0;
    return AnimatedPadding(
      duration: reduceMotion
          ? Duration.zero
          : ConversationTokens.motionDuration,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        keyboardVisible
            ? AiContentNotice.keyboardSpacing
            : AiContentNotice.bottomSpacing - noticeAdjustment,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NativeConversationModelSelector(
            key: const ValueKey('conversation-model'),
            name: widget.modelName,
            onPressed: _canChangeContext ? widget.onModels : null,
          ),
          const SizedBox(height: 8),
          _controls(),
          SizedBox(height: 8 + noticeAdjustment),
          const ConversationAiContentNotice(),
        ],
      ),
    );
  }
}
