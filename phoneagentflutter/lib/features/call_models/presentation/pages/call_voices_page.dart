import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/call_models.dart';
import '../../domain/system_voice_preview.dart';
import '../controller/system_voice_preview_controller.dart';
import '../controller/call_model_controller.dart';
import '../widgets/native_voice_selection_row.dart';
import '../widgets/clone_voice_card.dart';
import '../widgets/voice_catalog_status.dart';

class CallVoicesPage extends StatelessWidget {
  const CallVoicesPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onRetry,
    required this.onSelect,
    this.onSelectClone,
    this.onDeleteClone,
    this.onCreateClone,
    this.preview = const SystemVoicePreviewState(),
    this.onPreview,
  });
  final CallModelState state;
  final SystemVoicePreviewState preview;
  final ValueChanged<String>? onPreview;
  final VoidCallback onBack, onRetry;
  final ValueChanged<CallVoice> onSelect;
  final VoidCallback? onSelectClone;
  final VoidCallback? onCreateClone;
  final ValueChanged<String>? onDeleteClone;
  void _close(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
      onBack();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${state.voiceModelName} 的通话声音',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Semantics(
              container: true,
              button: true,
              label: '关闭音色选择',
              onTap: () => _close(context),
              excludeSemantics: true,
              child: IconButton(
                key: const ValueKey('backFromVoiceIdentity'),
                tooltip: '关闭音色选择',
                onPressed: () => _close(context),
                icon: const ExcludeSemantics(
                  child: Text(
                    '×',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 22, color: Color(0xFF8B8FA3)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (state.voiceSaving ||
          (state.voiceLoading && state.voices?.voices.isNotEmpty == true))
        const LinearProgressIndicator(minHeight: 2),
      Flexible(
        fit: FlexFit.loose,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          children: [
            VoiceCatalogStatus(state: state, onRetry: onRetry),
            if (onSelectClone != null)
              CloneVoiceCard(
                state: state,
                onSelect: onSelectClone!,
                onRefresh: onRetry,
                onDelete: onDeleteClone,
                onCreate: onCreateClone,
                previewLoading:
                    (preview.voiceId == cloneCurrentPreviewId ||
                        preview.voiceId == cloneCandidatePreviewId) &&
                    preview.phase == SystemVoicePreviewPhase.loading,
                previewPlaying:
                    (preview.voiceId == cloneCurrentPreviewId ||
                        preview.voiceId == cloneCandidatePreviewId) &&
                    preview.phase == SystemVoicePreviewPhase.playing,
                onPreview:
                    onPreview != null &&
                        state.clone?.canSelect == true &&
                        normalizeProvider(state.clone?.modelId ?? '') ==
                            normalizeProvider(state.cloneProvider) &&
                        !state.cloneLoading &&
                        !state.cloneNeedsRefresh &&
                        state.cloneError.isEmpty &&
                        state.voiceError.isEmpty &&
                        !state.voiceSaving &&
                        !state.voiceLoading &&
                        !state.saving
                    ? () => onPreview!(
                        state.clone!.candidateReady
                            ? cloneCandidatePreviewId
                            : cloneCurrentPreviewId,
                      )
                    : null,
              ),
            Container(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '系统音色',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (state.voices?.selectionMode == 'CLONE')
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        '当前使用克隆音色；选择下方 AI 音色将切换为系统音色。',
                        style: ShellTokens.subtitle,
                      ),
                    ),
                  VoiceCatalogStatus(
                    state: state,
                    onRetry: onRetry,
                    emptyOnly: true,
                  ),
                  if (preview.error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        preview.error,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE14D46),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  ...?state.voices?.voices.map(
                    (voice) => NativeVoiceSelectionRow(
                      key: ValueKey('voice-${voice.id}'),
                      voice: voice,
                      selected:
                          state.voices?.selectionMode == 'AI' &&
                          state.voices?.activeVoice == voice.id,
                      enabled:
                          !state.voiceSaving &&
                          !state.voiceLoading &&
                          !state.saving &&
                          !state.cloneNeedsRefresh,
                      onSelect: () => onSelect(voice),
                      showPreview: true,
                      previewLoading:
                          preview.voiceId == voice.id &&
                          preview.phase == SystemVoicePreviewPhase.loading,
                      previewPlaying:
                          preview.voiceId == voice.id &&
                          preview.phase == SystemVoicePreviewPhase.playing,
                      onPreview:
                          onPreview != null &&
                              voice.id.trim().isNotEmpty &&
                              !state.voiceSaving &&
                              !state.voiceLoading &&
                              !state.saving &&
                              !state.cloneNeedsRefresh
                          ? () => onPreview!(voice.id)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
