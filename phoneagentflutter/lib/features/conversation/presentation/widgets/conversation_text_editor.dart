import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'native_task_input_corner_icon.dart';
import 'native_task_submit_button.dart';

/// Full draft editor shares the compact controller and submission gate.
class ConversationTextEditor extends StatelessWidget {
  const ConversationTextEditor({
    super.key,
    required this.controller,
    required this.sendEnabled,
    required this.onChanged,
    required this.onSend,
    required this.stop,
  });
  final TextEditingController controller;
  final ValueListenable<bool> sendEnabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final ValueListenable<({VoidCallback? action, bool busy})> stop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final media = MediaQuery.of(context);
      final available =
          (bounds.maxHeight - media.viewInsets.bottom - media.padding.bottom)
              .clamp(0.0, bounds.maxHeight);
      return Padding(
        padding: EdgeInsets.only(
          bottom: media.viewInsets.bottom + media.padding.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: const ValueKey('conversation-expanded-sheet'),
            height: available * .85,
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 18, right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '任务内容',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('task-input-collapse'),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                          },
                          icon: Semantics(
                            label: '收起输入框',
                            child: const NativeTaskInputCornerIcon(
                              collapsed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: TextField(
                        key: const ValueKey('conversation-expanded-input'),
                        controller: controller,
                        autofocus: true,
                        onChanged: onChanged,
                        minLines: null,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 22 / 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '输入任务内容',
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          controller,
                          sendEnabled,
                          stop,
                        ]),
                        builder: (context, _) => NativeTaskSubmitButton(
                          buttonKey: const ValueKey('send-expanded-text'),
                          onStop: stop.value.action,
                          stopping: stop.value.busy,
                          canSend:
                              sendEnabled.value &&
                              controller.text.trim().isNotEmpty,
                          onSend: () {
                            onSend();
                            if (controller.text.isEmpty) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
