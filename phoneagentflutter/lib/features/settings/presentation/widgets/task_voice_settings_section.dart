import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/task_voice_settings_providers.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import 'task_voice_settings_sheet.dart';

class TaskVoiceSettingsSection extends ConsumerWidget {
  const TaskVoiceSettingsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskVoiceControllerProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '任务AI语音',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              '与你沟通任务时使用的声音',
              style: TextStyle(fontSize: 12, color: Color(0xFF8B919D)),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE6E9EE)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('task-voice-entry'),
              onTap: () {
                final container = ProviderScope.containerOf(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: const Color(0x73000000),
                  builder: (_) => RouteProviderScope(
                    container: container,
                    child: const TaskVoiceSettingsSheet(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.ready
                                ? state.voice.displayName
                                : state.error.isNotEmpty
                                ? '加载失败'
                                : '加载中',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            state.error.isNotEmpty
                                ? state.error
                                : state.voice.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B919D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      '›',
                      style: TextStyle(fontSize: 20, color: Color(0xFF8B919D)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                '选择后，下次任务语音回复生效',
                style: TextStyle(fontSize: 10, color: Color(0xFF8B8FA3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
