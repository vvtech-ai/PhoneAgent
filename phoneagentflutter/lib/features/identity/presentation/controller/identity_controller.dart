import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/identity_profile.dart';
import '../../domain/identity_deletion_cleanup.dart';

enum IdentityOperation { idle, loading, saving, deleting, cleaning }

enum IdentityOutcome { rejected, savedStay, savedReturn, deleted }

class IdentityState {
  const IdentityState({
    this.profile,
    this.draft = const IdentityDraft(),
    this.editing = false,
    this.operation = IdentityOperation.idle,
    this.error = '',
    this.cleanupPending = false,
    this.loadFailed = false,
  });
  final IdentityProfile? profile;
  final IdentityDraft draft;
  final bool editing;
  final IdentityOperation operation;
  final String error;
  final bool cleanupPending, loadFailed;
  bool get busy => operation != IdentityOperation.idle;
  bool get mutating => busy && operation != IdentityOperation.loading;
  bool get initialLoadStatus =>
      !editing &&
      (profile == null || profile!.status == IdentityStatus.empty) &&
      (operation == IdentityOperation.loading ||
          (loadFailed && error.isNotEmpty));
  IdentityState copy({
    IdentityProfile? profile,
    IdentityDraft? draft,
    bool? editing,
    IdentityOperation? operation,
    String? error,
    bool? cleanupPending,
    bool? loadFailed,
  }) => IdentityState(
    profile: profile ?? this.profile,
    draft: draft ?? this.draft,
    editing: editing ?? this.editing,
    operation: operation ?? this.operation,
    error: error ?? this.error,
    cleanupPending: cleanupPending ?? this.cleanupPending,
    loadFailed: loadFailed ?? this.loadFailed,
  );
}

class IdentityController extends StateNotifier<IdentityState> {
  IdentityController(
    this._repository, {
    IdentityDeletionCleanup Function()? createDeletionCleanup,
  }) : _createDeletionCleanup = createDeletionCleanup,
       super(const IdentityState());
  final IdentityRepository _repository;
  final IdentityDeletionCleanup Function()? _createDeletionCleanup;
  IdentityDeletionCleanup? _cleanup;
  Future<void> load() async {
    if (!mounted || state.busy || state.editing || state.cleanupPending) return;
    state = state.copy(
      operation: IdentityOperation.loading,
      error: '',
      loadFailed: false,
    );
    try {
      final profile = await _repository.load();
      if (!mounted) return;
      state = IdentityState(
        profile: profile,
        draft: IdentityDraft.from(profile),
      );
    } catch (_) {
      if (mounted) {
        state = state.copy(
          operation: IdentityOperation.idle,
          error: '身份资料加载失败，请重试',
          loadFailed: true,
        );
      }
    }
  }

  void beginEdit() {
    final profile = state.profile;
    if (state.busy || profile == null || state.cleanupPending) return;
    state = state.copy(
      editing: true,
      draft: IdentityDraft.from(profile),
      loadFailed: false,
      error: '',
    );
  }

  void cancelEdit() {
    if (state.busy || state.profile == null) return;
    state = state.copy(
      editing: false,
      draft: IdentityDraft.from(state.profile!),
      loadFailed: false,
      error: '',
    );
  }

  void edit({String? name, String? gender, String? phone}) {
    if (state.busy || !state.editing) return;
    state = state.copy(
      draft: state.draft.edit(
        name: state.profile?.status == IdentityStatus.verified ? null : name,
        gender: gender,
        phone: phone,
      ),
      error: '',
    );
  }

  Future<IdentityOutcome> save() async {
    final before = state.profile;
    if (state.busy || !state.editing || before == null) {
      return IdentityOutcome.rejected;
    }
    final error = state.draft.validation;
    if (error != null) {
      state = state.copy(
        error: error == IdentityValidation.nameRequired
            ? '请填写姓名'
            : '请输入正确的手机号码',
      );
      return IdentityOutcome.rejected;
    }
    state = state.copy(operation: IdentityOperation.saving, error: '');
    try {
      final profile = await _repository.save(
        state.draft,
        verified: before.status == IdentityStatus.verified,
      );
      if (!mounted) return IdentityOutcome.rejected;
      state = IdentityState(
        profile: profile,
        draft: IdentityDraft.from(profile),
      );
      return before.status == IdentityStatus.empty
          ? IdentityOutcome.savedStay
          : IdentityOutcome.savedReturn;
    } catch (_) {
      if (mounted) {
        state = state.copy(
          operation: IdentityOperation.idle,
          error: '身份资料保存失败，请重试',
        );
      }
      return IdentityOutcome.rejected;
    }
  }

  Future<IdentityOutcome> delete({required bool confirmed}) async {
    if (!mounted ||
        !confirmed ||
        state.busy ||
        state.profile == null ||
        state.cleanupPending) {
      return IdentityOutcome.rejected;
    }
    state = state.copy(operation: IdentityOperation.deleting, error: '');
    late final IdentityProfile profile;
    try {
      profile = await _repository.delete();
    } catch (_) {
      if (mounted) {
        state = state.copy(
          operation: IdentityOperation.idle,
          error: '删除身份失败，请重试',
        );
      }
      return IdentityOutcome.rejected;
    }
    if (!mounted) return IdentityOutcome.rejected;
    state = IdentityState(
      profile: profile,
      draft: IdentityDraft.from(profile),
      operation: IdentityOperation.deleting,
    );
    _cleanup = null;
    state = state.copy(cleanupPending: true);
    await retryCleanup();
    return mounted ? IdentityOutcome.deleted : IdentityOutcome.rejected;
  }

  Future<void> retryCleanup() async {
    if (!mounted ||
        !state.cleanupPending ||
        state.operation == IdentityOperation.cleaning) {
      return;
    }
    state = state.copy(operation: IdentityOperation.cleaning, error: '');
    try {
      _cleanup ??= _createDeletionCleanup?.call();
      await _cleanup?.run();
      if (mounted) {
        state = state.copy(
          operation: IdentityOperation.idle,
          cleanupPending: false,
        );
      }
    } catch (_) {
      // DELETE already succeeded; local failure must not invite another DELETE.
      if (mounted) {
        state = state.copy(
          operation: IdentityOperation.idle,
          error: '身份已删除，但本地录音清理或引导状态保存失败',
        );
      }
    }
  }
}
