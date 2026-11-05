import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../identity/domain/identity_profile.dart';
import '../../domain/initialization_gateway.dart';

class InitializationState {
  const InitializationState({
    this.step = 1,
    this.loading = false,
    this.saving = false,
    this.ready = false,
    this.finished = false,
    this.error = '',
    this.notice = '',
    this.draft = const IdentityDraft(),
    this.calls,
    this.callModel = '',
  });
  final int step;
  final bool loading, saving, ready, finished;
  final String error, callModel, notice;
  final IdentityDraft draft;
  final InitializationCatalog? calls;
  bool get busy => loading || saving;
  InitializationState copy({
    int? step,
    bool? loading,
    bool? saving,
    bool? ready,
    bool? finished,
    String? error,
    String? notice,
    IdentityDraft? draft,
    InitializationCatalog? calls,
    String? callModel,
  }) => InitializationState(
    step: step ?? this.step,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    ready: ready ?? this.ready,
    finished: finished ?? this.finished,
    error: error ?? this.error,
    notice: notice ?? this.notice,
    draft: draft ?? this.draft,
    calls: calls ?? this.calls,
    callModel: callModel ?? this.callModel,
  );
}

class InitializationController extends StateNotifier<InitializationState> {
  InitializationController(this.gateway, {this.onModelSwitch})
    : super(const InitializationState());
  final void Function(String, String)? onModelSwitch;
  final InitializationGateway gateway;
  String? _requestedCall;
  InitializationState get snapshot => state;
  Future<void> load() async {
    if (!mounted || state.busy || state.ready || state.finished) return;
    state = state.copy(loading: true, error: '');
    try {
      final skipped = await gateway.isSkipped();
      if (!mounted) return;
      if (skipped) {
        state = state.copy(loading: false, finished: true);
        return;
      }
      final profile = await gateway.loadIdentity();
      if (!mounted) return;
      if (profile.name.trim().isNotEmpty) {
        state = state.copy(loading: false, finished: true);
        return;
      }
      final calls = await gateway.loadCallModels();
      if (!mounted) return;
      state = state.copy(
        loading: false,
        ready: true,
        draft: IdentityDraft.from(profile),
        calls: calls,
        callModel: calls.permits('QWEN_OMNI_PLUS')
            ? 'QWEN_OMNI_PLUS'
            : calls.selected,
      );
    } catch (_) {
      if (mounted) state = state.copy(loading: false, error: '初始化资料加载失败，请重试');
    }
  }

  bool get _editable =>
      mounted && state.ready && !state.busy && !state.finished;
  void edit({String? name, String? gender, String? phone}) {
    if (!_editable || state.step != 1) return;
    state = state.copy(
      draft: state.draft.edit(name: name, gender: gender, phone: phone),
      error: '',
    );
  }

  void skipIdentity() {
    if (_editable && state.step == 1) state = state.copy(step: 2, error: '');
  }

  void back() {
    if (_editable && state.step > 1) {
      state = state.copy(step: state.step - 1, error: '');
    }
  }

  void select(String id) {
    if (!_editable) return;
    if (state.step == 2 && state.calls?.permits(id) == true) {
      state = state.copy(callModel: id, error: '');
    }
  }

  Future<void> _switchModel(String id, String name) async {
    try {
      await gateway.selectCallModel(id);
      if (mounted) state = state.copy(notice: '通话模型已切换为 $name');
    } catch (_) {
      if (mounted) state = state.copy(notice: '通话模型切换失败，请检查网络或本地服务连接');
    }
  }

  Future<void> next() async {
    if (!_editable) return;
    if (state.step == 1) {
      if (state.draft.name.trim().isNotEmpty) {
        state = state.copy(step: 2, error: '');
      }
      return;
    }
    if (state.calls?.permits(state.callModel) != true) {
      state = state.copy(error: '请选择可用模型');
      return;
    }
    if (state.draft.name.trim().isNotEmpty && state.draft.validation != null) {
      state = state.copy(error: '请输入正确的手机号码，可返回第一步修改');
      return;
    }
    state = state.copy(saving: true, error: '');
    var operation = '身份资料保存失败，请重试';
    try {
      if (_requestedCall != state.callModel) {
        _requestedCall = state.callModel;
        final name = state.calls!.models
            .firstWhere((m) => m.id == state.callModel)
            .name;
        if (onModelSwitch != null) {
          onModelSwitch!(state.callModel, name);
        } else {
          unawaited(_switchModel(state.callModel, name));
        }
      }
      if (state.draft.name.trim().isEmpty) {
        operation = '跳过状态尚未保存，请重试';
        await gateway.markSkipped();
      } else {
        operation = '身份资料保存失败，请重试';
        await gateway.saveIdentity(state.draft);
      }
      if (mounted) state = state.copy(saving: false, finished: true);
    } catch (_) {
      if (mounted) state = state.copy(saving: false, error: operation);
    }
  }
}
