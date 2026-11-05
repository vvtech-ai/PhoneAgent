import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/recording_providers.dart';
import '../widgets/recording_audio_card.dart';

class RecordingAudioRoute extends ConsumerWidget {
  const RecordingAudioRoute({super.key, required this.callId});
  final String callId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(recordingSupportedProvider)) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Text(
          '请在 Android 或 iOS App 中播放和保存录音；Web 可在开发者演练中验证交互。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    final provider = recordingAudioControllerProvider(callId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return RecordingAudioCard(
      state: state,
      onPrimary: controller.primary,
      onSave: controller.save,
    );
  }
}
