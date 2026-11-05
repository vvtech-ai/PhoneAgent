import '../../../settings/presentation/widgets/task_voice_settings_section.dart';
import '../widgets/native_clone_entry.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/call_models.dart';
import '../../domain/model_voice_summary.dart';
import '../../domain/call_model_quality.dart';
import '../../../../core/design/native_model_refresh_button.dart';
import '../controller/call_model_controller.dart';
import '../widgets/native_model_card.dart';
import '../../../commerce/domain/commerce_catalog.dart';
import '../../../commerce/domain/membership_access_hint.dart';

class CallModelsPage extends StatelessWidget {
  const CallModelsPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onRetry,
    required this.onSelect,
    required this.onVoices,
    this.onCreateClone,
    this.clonePricePoints,
    this.hasReadyClone = false,
    this.cloneReadFailed = false,
    this.sheet = false,
    this.readings = const {},
    this.qualityBusy = false,
    this.onRefreshQuality,
    this.membership,
    this.commerceCatalog,
    this.selectedModelId,
  });
  final CallModelState state;
  final VoidCallback onBack, onRetry;
  final VoidCallback? onCreateClone;
  final ValueChanged<CallModel> onSelect, onVoices;
  final bool sheet;
  final bool? hasReadyClone;
  final bool cloneReadFailed;
  final int? clonePricePoints;
  final Map<String, CallModelReading> readings;
  final bool qualityBusy;
  final VoidCallback? onRefreshQuality;
  final MembershipCurrent? membership;
  final CommerceCatalog? commerceCatalog;
  final String? selectedModelId;
  @override
  Widget build(BuildContext context) {
    final models = state.catalog?.models ?? [];
    final taskSelectionAvailable = models.any(
      (model) =>
          model.available &&
          normalizeProvider(model.id) ==
              normalizeProvider(selectedModelId ?? ''),
    );
    final selectedId = taskSelectionAvailable
        ? selectedModelId
        : state.catalog?.current?.id;
    return Column(
      mainAxisSize: sheet ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (!sheet)
          NativePageHeader(
            title: '语音模型与音色',
            onBack: onBack,
            backKey: const ValueKey('backFromVoiceModel'),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '选择 AI 通话模型',
                    style: TextStyle(
                      fontSize: 17,
                      height: 20 / 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                NativeModelRefreshButton(
                  busy: qualityBusy,
                  onRefresh: onRefreshQuality,
                ),
                Semantics(
                  container: true,
                  button: true,
                  enabled: true,
                  label: '关闭',
                  onTap: onBack,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: onBack,
                    tooltip: '关闭',
                    icon: const Icon(
                      Icons.close,
                      size: 22,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (state.loading || state.saving)
          const LinearProgressIndicator(minHeight: 2),
        Flexible(
          fit: sheet ? FlexFit.loose : FlexFit.tight,
          child: ListView(
            shrinkWrap: sheet,
            padding: EdgeInsets.fromLTRB(
              sheet ? 20 : 14,
              sheet ? 0 : 8,
              sheet ? 20 : 14,
              sheet ? 32 : 16,
            ),
            children: [
              if (!sheet) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '通话AI语音',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'AI 打电话时，对方听到的声音',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCreateClone != null) ...[
                  const SizedBox(height: 16),
                  NativeCloneEntry(
                    pricePoints: clonePricePoints,
                    onTap: state.saving ? null : onCreateClone,
                    hasReadyClone: hasReadyClone,
                    failed: cloneReadFailed,
                  ),
                ],
              ],
              if (state.error.isNotEmpty)
                _Retry(message: state.error, onRetry: onRetry),
              if (models.isEmpty && !state.loading && state.error.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无可用通话模型', textAlign: TextAlign.center),
                ),
              ...models.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    top: sheet && entry.key == 0 ? 0 : 10,
                  ),
                  child: NativeModelCard(
                    model: entry.value,
                    membershipHint:
                        commerceCatalog == null && membership == null
                        ? null
                        : MembershipAccessHint.model(
                            current: membership?.benefits,
                            published:
                                commerceCatalog?.benefitsByLevel ?? const {},
                            modelId: entry.value.id,
                            currentLevel: membership?.level,
                          ).message,
                    voiceSummary: sheet
                        ? null
                        : modelVoiceSummary(
                            entry.value,
                            activeProvider: state.catalog?.activeProvider,
                            voiceProvider: state.voiceProvider,
                            voices: state.voices,
                            unconfirmedCloneCandidate:
                                normalizeProvider(state.clone?.modelId ?? '') ==
                                    normalizeProvider(
                                      entry.value.capabilityProvider,
                                    ) &&
                                state.clone?.candidateReady == true,
                          ),
                    quick: sheet,
                    reading: readings[normalizeProvider(entry.value.id)],
                    selected:
                        entry.value.available &&
                        normalizeProvider(selectedId ?? '') ==
                            normalizeProvider(entry.value.id),
                    busy:
                        state.loading ||
                        state.saving ||
                        state.voiceSaving ||
                        state.error.isNotEmpty,
                    onSelect: () => onSelect(entry.value),
                    onVoices: sheet ? null : () => onVoices(entry.value),
                  ),
                ),
              ),
              Padding(
                padding: sheet
                    ? const EdgeInsets.only(top: 16)
                    : const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Text(
                  sheet ? '切换引擎后将在下次通话时生效' : '切换模型后将在下一次通话时生效',
                  style: TextStyle(
                    fontSize: sheet ? 12 : 10,
                    color: Color(0xFF8B8FA3),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (!sheet) const TaskVoiceSettingsSection(),
            ],
          ),
        ),
      ],
    );
  }
}

class SelectionIndicator extends StatelessWidget {
  const SelectionIndicator({super.key, required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Container(
      width: 21,
      height: 21,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ShellTokens.accent : const Color(0xFFD5D8E1),
          width: 2,
        ),
      ),
      child: selected
          ? const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ShellTokens.accent,
              ),
            )
          : null,
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(message, style: ShellTokens.subtitle),
      TextButton(onPressed: onRetry, child: const Text('重试')),
    ],
  );
}
