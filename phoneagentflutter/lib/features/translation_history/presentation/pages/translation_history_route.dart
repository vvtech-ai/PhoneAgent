import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_history_providers.dart';
import 'translation_history_page.dart';
import 'recording_audio_route.dart';

class TranslationHistoryRoute extends ConsumerWidget {
  const TranslationHistoryRoute({super.key, required this.callId});
  final String callId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: TranslationHistoryPage.background,
    body: SafeArea(
      child: TranslationHistoryPage(
        state: ref.watch(translationHistoryControllerProvider(callId)),
        onRetry: ref
            .read(translationHistoryControllerProvider(callId).notifier)
            .load,
        onClose: () => Navigator.of(context).pop(),
        recording: RecordingAudioRoute(key: ValueKey(callId), callId: callId),
      ),
    ),
  );
}
