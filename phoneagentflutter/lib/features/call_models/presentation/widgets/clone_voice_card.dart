import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../domain/clone_voice.dart';
import '../../domain/call_models.dart';
import '../controller/call_model_controller.dart';
import 'native_voice_selection_row.dart';
import 'clone_points_button.dart';

/// Clone state and actions share the native voice sheet's visual hierarchy.
class CloneVoiceCard extends StatelessWidget {
  const CloneVoiceCard({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onRefresh,
    this.onDelete,
    this.onCreate,
    this.onPreview,
    this.previewLoading = false,
    this.previewPlaying = false,
  });
  final CallModelState state;
  final VoidCallback onSelect, onRefresh;
  final ValueChanged<String>? onDelete;
  final VoidCallback? onCreate, onPreview;
  final bool previewLoading, previewPlaying;

  void _create(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
      onCreate?.call();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!state.canDeleteClone || onDelete == null) return;
    final target = state.voiceProvider!;
    final name = state.voiceModelName;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8A000000),
      builder: (_) => NativeConfirmationDialog(
        title: '删除 $name 克隆音色？',
        message: '$name 克隆音色将被删除。仅删除该模型的克隆音色并回退系统音色；保留身份、本地认证录音和其他模型克隆音色。',
        confirmLabel: '确认删除',
        danger: true,
      ),
    );
    if (context.mounted && confirmed == true) onDelete!(target);
  }

  @override
  Widget build(BuildContext context) {
    if (!supportsCloneVoice(state.cloneProvider)) {
      return const SizedBox.shrink();
    }
    final clone = state.clone;
    final price =
        !state.cloneLoading &&
            !state.cloneNeedsRefresh &&
            state.cloneError.isEmpty &&
            normalizeProvider(clone?.modelId ?? '') ==
                normalizeProvider(state.cloneProvider)
        ? clone?.pricePoints
        : null;
    final busy =
        state.voiceLoading ||
        state.cloneLoading ||
        state.voiceSaving ||
        state.saving;
    final selected = state.voices?.selectionMode.toUpperCase() == 'CLONE';
    final selectable =
        !busy &&
        !state.cloneNeedsRefresh &&
        state.cloneError.isEmpty &&
        state.voiceError.isEmpty &&
        clone?.canSelect == true &&
        (!selected || clone!.candidateReady);
    final status = state.cloneNeedsRefresh
        ? '等待同步'
        : state.cloneLoading
        ? '加载中…'
        : state.cloneError.isNotEmpty
        ? '读取失败'
        : clone?.candidateReady == true
        ? '新音色待确认'
        : clone?.hasProcessing == true
        ? '克隆处理中'
        : clone?.currentReady == true
        ? (selected ? '当前使用' : '可使用')
        : clone?.available == false
        ? '暂不可用'
        : '尚未克隆';
    final detail = state.cloneError.isNotEmpty
        ? state.cloneError
        : state.cloneNeedsRefresh
        ? '选择结果尚未同步，请先刷新；不会重复提交确认。'
        : clone?.candidateReady == true
        ? '新克隆音色已就绪并完成计费，选择后确认使用。'
        : clone?.hasProcessing == true
        ? '音色正在生成，可刷新查看最新状态。'
        : clone?.currentReady == true
        ? '使用已确认的个人音色，下次通话生效。'
        : clone?.unavailableReason.isNotEmpty == true
        ? clone!.unavailableReason
        : '还没有可选的克隆音色，可通过创建声音克隆完成认证和录制。';
    final available = clone?.canSelect == true;
    return Column(
      key: const ValueKey('cloneVoiceGroup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '我的克隆音色',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (onDelete != null &&
                clone?.currentReady == true &&
                clone?.candidateReady != true)
              IconButton(
                tooltip: '删除当前模型克隆音色',
                onPressed: state.canDeleteClone
                    ? () => _confirmDelete(context)
                    : null,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFF667085),
                ),
              ),
          ],
        ),
        if (available)
          NativeVoiceSelectionRow(
            key: const ValueKey('selectCloneVoice'),
            voice: CallVoice(
              '__CLONE__',
              clone!.candidateReady ? '确认使用新克隆音色' : '使用我的克隆音色',
              '',
              false,
            ),
            selected:
                selected && !clone.candidateReady && !state.cloneNeedsRefresh,
            enabled: selectable,
            onSelect: onSelect,
            showPreview: true,
            previewName: clone.candidateReady ? '新克隆音色' : '我的克隆音色',
            previewLoading: previewLoading,
            previewPlaying: previewPlaying,
            onPreview: onPreview,
          ),
        if (!available &&
            !busy &&
            !state.cloneNeedsRefresh &&
            state.cloneError.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final message = Text(
                  '当前模型暂无可用的克隆音色，完成声音克隆后即可使用',
                  style: ShellTokens.subtitle.copyWith(
                    fontSize: 12,
                    height: 1.5,
                  ),
                );
                if (onCreate == null) return message;
                final button = ClonePointsButton(
                  pricePoints: price,
                  buttonKey: const ValueKey('voice-create-clone'),
                  onPressed: () => _create(context),
                );
                final action = Semantics(
                  container: true,
                  button: true,
                  enabled: true,
                  label: ClonePointsButton.semanticLabel(price),
                  onTap: () => _create(context),
                  excludeSemantics: true,
                  child: button,
                );
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [message, const SizedBox(height: 12), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: message),
                    const SizedBox(width: 14),
                    action,
                  ],
                );
              },
            ),
          ),
        if (busy ||
            state.cloneNeedsRefresh ||
            state.cloneError.isNotEmpty ||
            clone?.hasProcessing == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              status,
              style: ShellTokens.subtitle.copyWith(fontSize: 12),
            ),
          ),
        if (state.cloneError.isNotEmpty ||
            state.cloneNeedsRefresh ||
            clone?.hasProcessing == true ||
            clone?.unavailableReason.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              detail,
              style: ShellTokens.subtitle.copyWith(fontSize: 12),
            ),
          ),
        if (state.cloneNeedsRefresh ||
            state.cloneError.isNotEmpty ||
            clone?.hasProcessing == true)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : onRefresh,
              child: Text(state.cloneNeedsRefresh ? '同步状态' : '刷新克隆状态'),
            ),
          ),
      ],
    );
  }
}
