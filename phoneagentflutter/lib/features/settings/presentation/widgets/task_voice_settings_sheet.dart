import 'dart:async';
import 'package:flutter/material.dart';
import 'task_voice_choice_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/task_voice_settings_providers.dart';
import '../../../../app/task_voice_preview_providers.dart';
import '../../../../app/business_providers.dart';
import '../controller/task_voice_preview_controller.dart';

class TaskVoiceSettingsSheet extends ConsumerStatefulWidget {
  const TaskVoiceSettingsSheet({super.key});
  @override
  ConsumerState<TaskVoiceSettingsSheet> createState() =>
      _TaskVoiceSettingsSheetState();
}

class _TaskVoiceSettingsSheetState extends ConsumerState<TaskVoiceSettingsSheet>
    with WidgetsBindingObserver {
  final _owner = Object();
  TaskVoicePreviewController? _preview;
  int? _epoch;
  String? _selectionMessage;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _epoch = ref.read(loginEpochProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_preview?.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_preview?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(taskVoiceControllerProvider);
    final controller = ref.read(taskVoiceControllerProvider.notifier);
    final preview = ref.watch(taskVoicePreviewProvider(_owner));
    _preview = ref.read(taskVoicePreviewProvider(_owner).notifier);
    ref.listen(loginEpochProvider, (_, epoch) {
      if (epoch != _epoch) {
        unawaited(_preview?.stop());
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '任务AI音色',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Text(
                          '×',
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF8B919D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (voice.busy) const LinearProgressIndicator(),
                if (voice.error.isNotEmpty)
                  Row(
                    children: [
                      Expanded(child: Text(voice.error)),
                      if (!voice.ready)
                        TextButton(
                          onPressed: controller.load,
                          child: const Text('重试'),
                        ),
                    ],
                  ),
                for (final item in voice.voices)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TaskVoiceChoiceRow(
                      voice: item,
                      selected: voice.voice == item,
                      previewing: preview.voice == item,
                      onSelect: voice.ready && !voice.busy
                          ? () async {
                              setState(() => _selectionMessage = null);
                              await controller.select(item);
                              if (!mounted ||
                                  ref.read(loginEpochProvider) != _epoch) {
                                return;
                              }
                              final saved = ref.read(
                                taskVoiceControllerProvider,
                              );
                              if (saved.error.isEmpty && saved.voice == item) {
                                setState(
                                  () => _selectionMessage =
                                      '已选择 ${item.displayName}',
                                );
                              }
                            }
                          : null,
                      onPreview: voice.ready
                          ? () {
                              setState(() => _selectionMessage = null);
                              _preview!.toggle(item);
                            }
                          : null,
                    ),
                  ),
                if (preview.error.isNotEmpty || _selectionMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        preview.error.isNotEmpty
                            ? preview.error
                            : _selectionMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0A84FF),
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
  }
}
