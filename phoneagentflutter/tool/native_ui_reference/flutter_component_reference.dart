import 'flutter_document_reference.dart';
import 'flutter_options_reference.dart';
import 'flutter_options_timeline_reference.dart';
import 'flutter_tasks_scroll_reference.dart';
import 'flutter_batch_result_reference.dart';
import 'flutter_conversation_header_reference.dart';
import 'flutter_contacts_skills_reference.dart';
import 'flutter_contacts_remark_reference.dart';
import 'flutter_contacts_reference.dart';
import 'flutter_clone_result_reference.dart';
import 'flutter_clone_processing_reference.dart';
import 'flutter_clone_identity_reference.dart';
import 'flutter_clone_consent_reference.dart';
import 'flutter_voices_reference.dart';
import 'flutter_original_audio_reference.dart';
import 'flutter_identity_reference.dart';
import 'flutter_models_reference.dart';
import 'flutter_settings_reference.dart';
import 'flutter_ledger_reference.dart';
import 'package:phone_agent/core/design/native_system_chrome.dart';
import 'package:flutter/material.dart';
import 'flutter_rules_reference.dart';
import 'flutter_points_reference.dart';
import 'package:flutter/services.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_record_card.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_sync_surface.dart';
import 'package:phone_agent/core/design/auth_tokens.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

const _transcripts = [
  TranslationTranscript(
    id: '1',
    leg: 'user',
    source: '请问几点营业？',
    translated: 'What time do you open?',
    sourceLanguage: 'zh',
    translatedLanguage: 'en',
    isFinal: true,
  ),
  TranslationTranscript(
    id: '2',
    leg: 'merchant',
    source: 'We open at nine.',
    translated: '我们九点营业。',
    sourceLanguage: 'en',
    translatedLanguage: 'zh',
    isFinal: true,
  ),
];

const _scene = String.fromEnvironment('UI_REFERENCE_SCENE');

// Rendering only: synthetic local providers in preference scenes; no service or device IO.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: NativeSystemChrome.light,
      child: child!,
    ),
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AuthTokens.accent,
      ).copyWith(primary: AuthTokens.accent),
    ),
    home: _scene == 'tasks-scroll'
        ? const FlutterTasksScrollReference()
        : _scene == 'options-timeline'
        ? const FlutterOptionsTimelineReference()
        : _scene == 'options'
        ? const FlutterOptionsReference()
        : _scene == 'document'
        ? const FlutterDocumentReference()
        : _scene.startsWith('batch-result')
        ? FlutterBatchResultReference(
            withTranscript: _scene == 'batch-result-transcript',
          )
        : _scene.startsWith('conversation-header') ||
              _scene == 'conversation-opening' ||
              _scene.startsWith('conversation-wave') ||
              _scene == 'conversation-model' ||
              _scene == 'conversation-voice-finalizing' ||
              _scene == 'conversation-voice-press'
        ? FlutterConversationHeaderReference(scene: _scene)
        : _scene.startsWith('contacts-skills')
        ? FlutterContactsSkillsReference(scene: _scene)
        : _scene.startsWith('contacts-remark')
        ? FlutterContactsRemarkReference(scene: _scene)
        : _scene.startsWith('contacts')
        ? FlutterContactsReference(scene: _scene)
        : _scene.startsWith('clone-result')
        ? FlutterCloneResultReference(scene: _scene)
        : const [
            'clone-collecting',
            'clone-checking',
            'clone-generating',
            'clone-processing-error',
          ].contains(_scene)
        ? FlutterCloneProcessingReference(scene: _scene)
        : _scene.startsWith('clone-identity')
        ? FlutterCloneIdentityReference(scene: _scene)
        : _scene.startsWith('clone-consent')
        ? FlutterCloneConsentReference(scene: _scene)
        : _scene.startsWith('identity')
        ? FlutterIdentityReference(scene: _scene)
        : _scene == 'original-audio'
        ? const FlutterOriginalAudioReference()
        : _scene == 'voices'
        ? const FlutterVoicesReference()
        : _scene == 'models'
        ? const FlutterModelsReference()
        : _scene == 'settings'
        ? const FlutterSettingsReference()
        : _scene.startsWith('ledger')
        ? const FlutterLedgerReference(scene: _scene)
        : const String.fromEnvironment('UI_REFERENCE_SCENE') == 'wallet'
        ? const FlutterPointsReference()
        : const String.fromEnvironment('UI_REFERENCE_SCENE') == 'rules'
        ? const FlutterRulesReference()
        : const String.fromEnvironment('UI_REFERENCE_SCENE') == 'tasks'
        ? const _TaskReference()
        : TranslationCallPage(
            state: const TranslationCallView(
              phase: TranslationPhase.translating,
              elapsedSeconds: 65,
              dialPad: true,
              dtmfFeedbackAvailable: true,
              transcripts: _transcripts,
            ),
            target: '合成翻译对象',
            controls: TranslationCallControls(
              state: const TranslationCallView(
                phase: TranslationPhase.translating,
                elapsedSeconds: 65,
                dialPad: true,
                dtmfFeedbackAvailable: true,
                transcripts: _transcripts,
              ),
              onMute: () {},
              onSpeaker: () {},
              onPad: () {},
              onDigit: (_) {},
              onHangup: () {},
            ),
          ),
  ),
);

class _TaskReference extends StatelessWidget {
  const _TaskReference();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFBFCFD),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskRecordCard(
              title: 'MOCK · 单路回执与评分',
              detail: '9月20日 09:00',
              status: '已完成',
              statusColor: const Color(0xFF1F8F46),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            const TaskSyncSurface(error: false),
            const SizedBox(height: 10),
            TaskSyncSurface(error: true, onRetry: () {}),
            const TaskInitialLoading(),
          ],
        ),
      ),
    ),
  );
}
