import 'package:flutter/material.dart';
import '../../domain/task_rating_draft_store.dart';
import '../controller/task_rating_controller.dart';

class TaskRatingSheet extends StatelessWidget {
  const TaskRatingSheet({
    super.key,
    required this.state,
    required this.onClose,
    required this.onRate,
    required this.onSkipClone,
    required this.onSuggestion,
    required this.onSubmit,
    required this.onRetryDraft,
  });
  final TaskRatingState state;
  final VoidCallback onClose, onSubmit, onRetryDraft;
  final void Function(RatingDimension, int) onRate;
  final ValueChanged<bool> onSkipClone;
  final ValueChanged<String> onSuggestion;
  @override
  Widget build(BuildContext context) {
    final enabled = state.canEdit;
    final draft = state.draft;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.readOnly ? '查看评分' : '评价本次任务',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF14213D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  enabled: !state.saving,
                  label: '关闭评分',
                  onTap: state.saving ? null : onClose,
                  excludeSemantics: true,
                  child: IconButton(
                    tooltip: '关闭评分',
                    onPressed: state.saving ? null : onClose,
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF475467),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.loading || state.draftReadFailed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.loading ? '正在读取草稿…' : state.error),
                        TextButton(
                          onPressed: state.loading ? null : onRetryDraft,
                          child: const Text('重新读取草稿'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Text(
                        state.readOnly
                            ? '以下是已提交的评分，仅供查看。'
                            : '请选择最符合你实际感受的选项，没有默认答案。${state.rewardHint == null ? '' : '\n${state.rewardHint}，积分与评价结果无关。'}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 19 / 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                      _section(
                        'AI大模型对任务的理解',
                        'AI是否正确理解了会议资料、联系人和邀请要求？',
                        RatingDimension.understanding,
                        draft.taskUnderstanding,
                        enabled,
                      ),
                      _section(
                        'AI通话表现',
                        '本次AI通话的整体表现如何？',
                        RatingDimension.call,
                        draft.aiCallPerformance,
                        enabled,
                      ),
                      if (state.eligibility?.cloneVoiceAvailable == true) ...[
                        _section(
                          '克隆音色表现',
                          '本次克隆音色的整体表现如何？',
                          RatingDimension.clone,
                          draft.cloneVoicePerformance,
                          enabled,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              container: true,
                              selected: draft.cloneVoiceNotEvaluated,
                              button: true,
                              enabled: enabled,
                              label: '未试听 / 不评价',
                              onTap: enabled
                                  ? () => onSkipClone(
                                      !draft.cloneVoiceNotEvaluated,
                                    )
                                  : null,
                              excludeSemantics: true,
                              child: TextButton(
                                onPressed: enabled
                                    ? () => onSkipClone(
                                        !draft.cloneVoiceNotEvaluated,
                                      )
                                    : null,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  backgroundColor: draft.cloneVoiceNotEvaluated
                                      ? const Color(0xFFDCEEFF)
                                      : const Color(0xFFF5F7FA),
                                  side: BorderSide(
                                    color: draft.cloneVoiceNotEvaluated
                                        ? const Color(0xFF9ACBFF)
                                        : Colors.transparent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  '未试听 / 不评价',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: draft.cloneVoiceNotEvaluated
                                        ? const Color(0xFF1687F8)
                                        : const Color(0xFF475467),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      _section(
                        '任务完成度',
                        '本次任务目标的达成情况如何？',
                        RatingDimension.completion,
                        draft.taskCompletion,
                        enabled,
                      ),
                      _divider(16),
                      _heading('其他建议', '选填'),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: ValueKey('rating-suggestion-${state.readOnly}'),
                        initialValue: draft.suggestion,
                        enabled: enabled,
                        readOnly: state.readOnly,
                        minLines: 4,
                        maxLines: 5,
                        onChanged: onSuggestion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF14213D),
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD0D5DD)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD0D5DD)),
                          ),
                          constraints: BoxConstraints(minHeight: 112),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF98A2B3),
                          ),
                          hintText: '可以告诉我们哪些地方做得好，或还需要改进',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${draft.suggestion.runes.length}/300',
                          style: TextStyle(
                            fontSize: 10,
                            color: draft.suggestion.runes.length > 300
                                ? const Color(0xFFD92D20)
                                : const Color(0xFF667085),
                          ),
                        ),
                      ),
                      if (state.error.isNotEmpty)
                        Text(
                          state.error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],
                  ),
          ),
          if (!state.readOnly)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1687F8),
                    disabledBackgroundColor: const Color(0xFFB4D6F2),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: state.canSubmit ? onSubmit : null,
                  child: Text(state.saving ? '提交中…' : '提交评价'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider(double top) => Column(
    children: [
      SizedBox(height: top),
      const Divider(height: 1, thickness: 1, color: Color(0xFFE8EDF3)),
      const SizedBox(height: 14),
    ],
  );
  Widget _heading(String title, String tag) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF14213D),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(tag, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
    ],
  );

  Widget _section(
    String title,
    String description,
    RatingDimension dimension,
    int? selected,
    bool enabled,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _divider(12),
      _heading(title, '必填'),
      const SizedBox(height: 5),
      Text(
        description,
        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          for (var score = 1; score <= 5; score++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Semantics(
                  label: '$title $score分',
                  selected: selected == score,
                  button: true,
                  enabled: enabled,
                  onTap: enabled ? () => onRate(dimension, score) : null,
                  child: ExcludeSemantics(
                    child: TextButton(
                      key: ValueKey('rating-${dimension.name}-$score'),
                      onPressed: enabled
                          ? () => onRate(dimension, score)
                          : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: selected == score
                            ? const Color(0xFFDCEEFF)
                            : const Color(0xFFF0F3F7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: selected == score
                              ? const Color(0xFF1687F8)
                              : const Color(0xFF14213D),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
