import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invite.dart';
import '../../domain/invite_activity_failure.dart';
import '../../domain/invite_device.dart';
import 'pending_invite_controller.dart' show inviteRequestId;

class InviteState {
  const InviteState({
    this.overview,
    this.code,
    this.loading = false,
    this.acting = false,
    this.error = '',
    this.notice = '',
    this.actionType = '',
  });
  final InviteOverview? overview;
  final InviteCode? code;
  final bool loading, acting;
  final String error, notice, actionType;
  InviteState copy({
    InviteOverview? overview,
    InviteCode? code,
    bool clearCode = false,
    bool clearOverview = false,
    bool? loading,
    bool? acting,
    String? error,
    String? notice,
    String? actionType,
  }) => InviteState(
    overview: clearOverview ? null : overview ?? this.overview,
    code: clearCode ? null : code ?? this.code,
    loading: loading ?? this.loading,
    acting: acting ?? this.acting,
    error: error ?? this.error,
    notice: notice ?? this.notice,
    actionType: actionType ?? this.actionType,
  );
}

class InviteController extends StateNotifier<InviteState> {
  InviteController(this.repository, this.device) : super(const InviteState());
  final InviteRepository repository;
  final InviteDevice device;
  int _generation = 0;
  bool _refreshRequested = false;
  bool get canShare => !state.loading && !state.acting && state.code != null;

  Future<void> refresh() async {
    if (!mounted) return;
    if (state.loading || state.acting) {
      _refreshRequested = true;
      return;
    }
    final generation = ++_generation;
    state = state.copy(
      loading: true,
      clearCode: true,
      clearOverview: true,
      error: '',
      notice: '',
    );
    try {
      final overview = await repository.activity();
      if (!_current(generation)) return;
      final code = overview.activity == null ? null : await repository.code();
      if (!_current(generation)) return;
      if (code != null &&
          (code.overview.activity == null ||
              code.overview.activity!.id.trim().isEmpty)) {
        throw const InviteFailure('INVITE_ACTIVITY_CHANGED');
      }
      state = state.copy(
        code: code,
        overview: code?.overview ?? overview,
        error: overview.activity == null ? '活动尚未发布' : '',
      );
    } catch (e) {
      if (_current(generation)) {
        state = state.copy(error: inviteActivityFailureMessage(e));
      }
    } finally {
      if (_current(generation)) {
        state = state.copy(loading: false);
        await _refreshIfRequested();
      }
    }
  }

  Future<void> copy(bool link) async {
    if (!canShare) {
      state = state.copy(notice: '邀请信息已失效，请刷新');
      return;
    }
    final code = state.code!;
    await _action(link ? 'COPY_LINK' : 'COPY_CODE', () async {
      await device.copy(link ? code.url : code.code);
      return true;
    }, '已复制');
  }

  Future<void> savePoster(
    InviteCode snapshot,
    Future<Uint8List> Function() render,
  ) async {
    if (!canShare || !identical(snapshot, state.code)) {
      state = state.copy(notice: '邀请信息已变化，请重新打开海报');
      return;
    }
    await _action('SAVE_POSTER', () async {
      final bytes = await render();
      if (!mounted || !identical(snapshot, state.code)) return false;
      return device.savePoster(bytes);
    }, '邀请图片已保存');
  }

  Future<void> _action(
    String type,
    Future<bool> Function() action,
    String success,
  ) async {
    final generation = _generation;
    final period = state.code?.overview.activity?.id;
    if (period == null) return;
    state = state.copy(acting: true, actionType: type, notice: '');
    try {
      final saved = await action();
      if (!_current(generation)) return;
      state = state.copy(
        acting: false,
        actionType: '',
        notice: saved ? success : '已取消保存',
      );
      if (saved) {
        unawaited(_recordEvent(period, type));
      }
    } catch (_) {
      if (_current(generation)) {
        state = state.copy(
          acting: false,
          actionType: '',
          notice: '操作失败，请检查权限后重试',
        );
      }
    } finally {
      if (_current(generation)) await _refreshIfRequested();
    }
  }

  Future<void> _recordEvent(String period, String type) async {
    try {
      await repository.event(period, type, inviteRequestId());
    } catch (_) {
      /* Statistics do not undo the user's completed action. */
    }
  }

  Future<void> _refreshIfRequested() async {
    if (!mounted || !_refreshRequested) return;
    _refreshRequested = false;
    await refresh();
  }

  bool _current(int generation) => mounted && generation == _generation;
}
