import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart' show appRouterProvider;
import 'package:phone_agent/app/recording_providers.dart';
import 'package:phone_agent/app/translation_history_providers.dart';
import 'package:phone_agent/features/translation_history/data/preview_recording_audio.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';

RecordingPreviewScenario shellRecordingScenario(String name) {
  for (final scenario in RecordingPreviewScenario.values) {
    if (scenario.name == name) return scenario;
  }
  throw ArgumentError.value(
    name,
    'name',
    'Unknown synthetic recording scenario',
  );
}

/// Tool-only external ports. No production URI, native audio or file operations.
List<Override> shellHistoryOverrides(BuildContext context) => [
  translationHistoryRepositoryProvider.overrideWithValue(
    const ShellHistoryPreview(),
  ),
  recordingSupportedProvider.overrideWithValue(true),
  recordingAudioControllerProvider.overrideWith((ref, callId) {
    ref.watch(loginEpochProvider);
    ShellHistoryPreview.checkId(callId);
    var closed = false;
    ref.onDispose(() => closed = true);
    final scenario = shellRecordingScenario(
      const String.fromEnvironment(
        'UI_RECORDING_SCENARIO',
        defaultValue: 'normal',
      ),
    );
    final controller = RecordingAudioController(
      repository: PreviewRecordingRepository(scenario),
      player: PreviewRecordingPlayer(scenario),
      exporter: PreviewRecordingExporter(() async {
        if (closed || !context.mounted) return false;
        final navigatorContext = ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentContext;
        if (navigatorContext == null || !navigatorContext.mounted) return false;
        return await showDialog<bool>(
              context: navigatorContext,
              builder: (dialog) => AlertDialog(
                title: const Text('MOCK · 保存录音'),
                content: const Text('仅模拟选择保存位置，不读取或写入真实文件。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('取消保存'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('模拟保存'),
                  ),
                ],
              ),
            ) ??
            false;
      }, scenario),
      isCurrent: () => !closed && context.mounted,
      logicalDurationMillis: PreviewRecordingPlayer.durationMillis,
    );
    controller.load();
    return controller;
  }),
];

class ShellHistoryPreview implements TranslationHistoryRepository {
  const ShellHistoryPreview();

  static void checkId(String callId) {
    if (!const {'tr1', 'tr2'}.contains(callId)) {
      throw StateError('Unknown synthetic translation record');
    }
  }

  @override
  Future<TranslationHistory> load(String callId) async {
    checkId(callId);
    final second = callId == 'tr2';
    return TranslationHistory(
      callId: callId,
      route: TranslationRoute.worldCall,
      targetName: second ? '合成酒店前台' : '合成翻译对象',
      phoneNumber: second ? '+12025550124' : '+12025550123',
      myLanguage: 'zh-CN',
      peerLanguage: 'en-US',
      connectedAt: second ? '2026-09-16T10:30:00' : '2026-09-16T11:00:00',
      endedAt: second ? '2026-09-16T10:30:12' : '2026-09-16T11:00:12',
      durationMillis: PreviewRecordingPlayer.durationMillis,
      recording: const TranslationRecording(source: 'MOCK'),
      transcripts: [
        TranslationTranscript(
          segmentId: '$callId:local',
          sourceLeg: 'local',
          sourceLanguage: 'zh-CN',
          sourceText: second ? '请问几点可以办理入住？' : '请确认今天的营业时间。',
          translatedLanguage: 'en-US',
          translatedText: second
              ? 'What time can I check in?'
              : 'Please confirm today’s opening hours.',
          isFinal: true,
        ),
        TranslationTranscript(
          segmentId: '$callId:merchant',
          sourceLeg: 'merchant',
          sourceLanguage: 'en-US',
          sourceText: second
              ? 'Check-in starts at three in the afternoon.'
              : 'We are open until eight this evening.',
          translatedLanguage: 'zh-CN',
          translatedText: second ? '下午三点可以办理入住。' : '今天营业到晚上八点。',
          isFinal: true,
        ),
      ],
    );
  }
}
