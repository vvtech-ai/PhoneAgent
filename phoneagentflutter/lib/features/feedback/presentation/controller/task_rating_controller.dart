import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/call_evaluation.dart';
import '../../domain/task_rating.dart';
import '../../domain/task_rating_draft_store.dart';

class TaskRatingState {
  const TaskRatingState({
    this.eligibility,
    this.draft = const TaskRatingDraft(),
    this.owner,
    this.sheetOpen = false,
    this.saving = false,
    this.loading = false,
    this.draftReadFailed = false,
    this.success = false,
    this.error = '',
  });
  final TaskRatingEligibility? eligibility;
  final TaskRatingDraft draft;
  final Object? owner;
  final bool sheetOpen, saving, success, loading, draftReadFailed;
  final String error;
  bool get visible => eligibility?.eligible == true;
  bool get readOnly => eligibility?.readOnly == true;
  bool get canEdit =>
      visible && !readOnly && !saving && !loading && !draftReadFailed;
  bool get canSubmit =>
      canEdit &&
      draft.valid(cloneVoiceAvailable: eligibility!.cloneVoiceAvailable);
  String? get rewardHint {
    final e = eligibility;
    if (readOnly || e?.rewardEnabled != true || (e?.rewardPoints ?? 0) <= 0) {
      return null;
    }
    return '提交后可获得${e!.rewardPoints}积分';
  }

  TaskRatingState copy({
    TaskRatingEligibility? eligibility,
    TaskRatingDraft? draft,
    Object? owner,
    bool clearOwner = false,
    bool? sheetOpen,
    bool? saving,
    bool? loading,
    bool? draftReadFailed,
    bool? success,
    String? error,
  }) => TaskRatingState(
    eligibility: eligibility ?? this.eligibility,
    draft: draft ?? this.draft,
    owner: clearOwner ? null : owner ?? this.owner,
    sheetOpen: sheetOpen ?? this.sheetOpen,
    saving: saving ?? this.saving,
    loading: loading ?? this.loading,
    draftReadFailed: draftReadFailed ?? this.draftReadFailed,
    success: success ?? this.success,
    error: error ?? this.error,
  );
}

class TaskRatingController extends StateNotifier<TaskRatingState> {
  TaskRatingController({
    required this.target,
    required TaskRatingRepository repository,
    required TaskRatingDraftStore drafts,
    required FutureOr<String> clientVersion,
    Future<void> Function()? onSubmitted,
    String Function()? newKey,
  }) : _repository = repository,
       _drafts = drafts,
       _clientVersion = clientVersion,
       _onSubmitted = onSubmitted,
       _newKey = newKey ?? _randomKey,
       super(const TaskRatingState());
  final FeedbackTarget target;
  final TaskRatingRepository _repository;
  final TaskRatingDraftStore _drafts;
  final FutureOr<String> _clientVersion;
  final Future<void> Function()? _onSubmitted;
  final String Function() _newKey;
  String _submissionKey = '';
  int _generation = 0, _edit = 0;
  bool _hasClaimed = false, _refreshPending = false;
  bool get submittedSuccessfully => state.success;
  int? get grantedPoints => state.eligibility?.grantedPoints;
  static String _randomKey() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void refresh() {
    if (!mounted || state.readOnly) return;
    if (state.saving || state.sheetOpen) {
      _refreshPending = true;
      return;
    }
    _refreshPending = false;
    unawaited(load());
  }

  Future<void> load() async {
    if (!mounted || state.saving || state.sheetOpen) return;
    final generation = ++_generation;
    state = state.copy(loading: true);
    try {
      final version = await _clientVersion;
      if (!mounted || generation != _generation) return;
      final e = await _repository.eligibility(
        target,
        clientVersion: version,
      );
      if (!mounted || generation != _generation) return;
      if (!e.eligible ||
          e.target != target ||
          e.id.isEmpty ||
          e.taskId.isEmpty ||
          e.taskType.isEmpty) {
        state = TaskRatingState(owner: state.owner);
        return;
      }
      await _restoreDraft(e, generation);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = TaskRatingState(owner: state.owner);
      }
    }
  }

  Future<void> retryDraft() async {
    if (!mounted || !state.draftReadFailed || state.loading || state.saving) {
      return;
    }
    state = state.copy(loading: true, error: '');
    await _restoreDraft(state.eligibility!, ++_generation);
  }

  Future<void> _restoreDraft(TaskRatingEligibility e, int generation) async {
    SavedRatingDraft? saved;
    try {
      saved = e.readOnly ? null : await _drafts.read(e);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = state.copy(
          eligibility: e,
          loading: false,
          draftReadFailed: true,
          error: '草稿读取失败，请重试后再编辑',
        );
      }
      return;
    }
    if (!mounted || generation != _generation) return;
    _submissionKey = saved?.submissionKey ?? '';
    var draft =
        e.currentSubmission?.draft ?? saved?.draft ?? const TaskRatingDraft();
    if (!e.cloneVoiceAvailable) draft = draft.edit(skipClone: true);
    state = TaskRatingState(
      eligibility: e,
      draft: draft,
      owner: state.owner,
      sheetOpen: state.sheetOpen,
    );
    if (e.readOnly) {
      try {
        await _drafts.clear(e);
      } catch (_) {
        /* Server submission is authoritative. */
      }
    }
  }

  void claim(Object owner) {
    if (!mounted || state.owner != null) return;
    state = state.copy(owner: owner);
    if (_hasClaimed) refresh();
    _hasClaimed = true;
  }

  void release(Object owner) {
    if (mounted && identical(state.owner, owner)) {
      state = state.copy(clearOwner: true);
    }
  }

  void open() {
    if (state.visible && !state.saving) {
      state = state.copy(
        sheetOpen: true,
        error: state.draftReadFailed ? state.error : '',
      );
    }
  }

  void close() {
    if (!state.saving) {
      state = state.copy(
        sheetOpen: false,
        error: state.draftReadFailed ? state.error : '',
      );
      if (_refreshPending) refresh();
    }
  }

  void dismissSuccess() => state = state.copy(success: false);
  void rate(RatingDimension dimension, int score) {
    if (score < 1 ||
        score > 5 ||
        (dimension == RatingDimension.clone &&
            state.eligibility?.cloneVoiceAvailable != true)) {
      return;
    }
    _update(state.draft.edit(dimension: dimension, score: score));
  }

  void skipClone(bool value) {
    if (state.eligibility?.cloneVoiceAvailable == true) {
      _update(state.draft.edit(skipClone: value));
    }
  }

  void suggestion(String value) => _update(state.draft.edit(text: value));
  void _update(TaskRatingDraft draft) {
    if (!state.canEdit) return;
    _submissionKey = '';
    final revision = ++_edit;
    state = state.copy(
      draft: draft,
      error: draft.suggestion.runes.length > 300 ? '其他建议最多300字' : '',
    );
    unawaited(
      _drafts.save(state.eligibility!, SavedRatingDraft(draft)).catchError((
        Object _,
      ) {
        if (mounted && revision == _edit && state.canEdit) {
          state = state.copy(error: '草稿暂未保存，请勿离开页面');
        }
      }),
    );
  }

  Future<void> submit() async {
    if (!mounted || !state.canSubmit || !state.sheetOpen) return;
    final e = state.eligibility!, draft = state.draft;
    if (_submissionKey.isEmpty) _submissionKey = _newKey();
    state = state.copy(saving: true, error: '');
    try {
      // Durable key before POST makes an ambiguous response retry safe.
      await _drafts.save(
        e,
        SavedRatingDraft(draft, submissionKey: _submissionKey),
      );
      if (!mounted) return;
      final submission = await _repository.submit(
        e,
        draft,
        idempotencyKey: _submissionKey,
      );
      if (!mounted) return;
      final result = TaskRatingEligibility(
        target: e.target,
        eligible: e.eligible,
        id: e.id,
        taskType: e.taskType,
        taskId: e.taskId,
        status: e.status,
        cloneVoiceAvailable: e.cloneVoiceAvailable,
        rewardEnabled: e.rewardEnabled,
        rewardPoints: e.rewardPoints,
        currentSubmission: submission,
      );
      state = state.copy(
        eligibility: result,
        draft: submission.draft,
        saving: false,
        sheetOpen: false,
        success: true,
      );
      // Cleanup / wallet failure must never turn accepted submission into retry.
      try {
        await _drafts.clear(e);
      } catch (_) {
        /* Server wins on next load. */
      }
      if (mounted) {
        try {
          await _onSubmitted?.call();
        } catch (_) {
          /* Wallet owns retry state. */
        }
      }
    } catch (_) {
      if (mounted) state = state.copy(saving: false, error: '评价提交失败，请重试');
    }
  }
}
