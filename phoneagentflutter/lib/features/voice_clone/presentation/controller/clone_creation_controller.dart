import '../../domain/clone_price_policy.dart';
import '../../domain/clone_entitlement.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/clone_creation.dart';

class CloneCreationState {
  const CloneCreationState({
    this.models = const [],
    this.loading = false,
    this.busy = false,
    this.selected,
    this.confirmReauthentication = false,
    this.launch,
    this.error = '',
    this.entitlementDenied = false,
    this.entitlementUnknown = false,
  });
  final List<CloneCreationModel> models;
  final bool loading, busy, confirmReauthentication;
  final CloneCreationModel? selected;
  final CloneCreationLaunch? launch;
  final String error;
  final bool entitlementDenied, entitlementUnknown;
  CloneCreationState copy({
    List<CloneCreationModel>? models,
    bool? loading,
    bool? busy,
    CloneCreationModel? selected,
    bool? confirmReauthentication,
    CloneCreationLaunch? launch,
    String? error,
    bool? entitlementDenied,
    bool? entitlementUnknown,
  }) => CloneCreationState(
    models: models ?? this.models,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    selected: selected ?? this.selected,
    confirmReauthentication:
        confirmReauthentication ?? this.confirmReauthentication,
    launch: launch ?? this.launch,
    error: error ?? this.error,
    entitlementDenied: entitlementDenied ?? this.entitlementDenied,
    entitlementUnknown: entitlementUnknown ?? this.entitlementUnknown,
  );
}

class CloneCreationController extends StateNotifier<CloneCreationState> {
  CloneCreationController(this.port) : super(const CloneCreationState());
  final CloneCreationPort port;
  bool get _blocked =>
      !mounted || state.busy || state.loading || state.launch != null;

  Future<void> load() async {
    if (_blocked || state.confirmReauthentication) return;
    state = state.copy(
      loading: true,
      error: '',
      entitlementDenied: false,
      entitlementUnknown: false,
    );
    try {
      final models = await port.models();
      if (mounted) {
        final denied =
            models.isNotEmpty &&
            models.every((m) => cloneEntitlement(m) == CloneEntitlement.denied);
        final unknown =
            models.isNotEmpty &&
            !denied &&
            models.every(
              (m) => cloneEntitlement(m) != CloneEntitlement.allowed,
            );
        state = state.copy(
          models: models,
          loading: false,
          entitlementDenied: denied,
          entitlementUnknown: unknown,
          error: unknown ? cloneEntitlementUnavailable : '',
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copy(
          loading: false,
          error: error is CloneCatalogFailure
              ? error.message
              : CloneCatalogFailure.serviceUnavailable.message,
        );
      }
    }
  }

  void dismissEntitlement() {
    if (!_blocked) state = state.copy(entitlementDenied: false);
  }

  Future<void> select(String modelId) async {
    if (_blocked || state.confirmReauthentication) return;
    final matches = state.models.where((m) => m.id == modelId);
    if (matches.length != 1) {
      state = state.copy(error: '当前模型暂不可用，请返回后重试');
      return;
    }
    final model = await _refresh(matches.single);
    if (!mounted || model == null) return;
    state = state.copy(selected: model, error: '');
    if (model.requiresReauthentication) {
      state = state.copy(confirmReauthentication: true);
    } else if (model.hasCandidate && !model.candidateFailed) {
      state = state.copy(
        launch: CloneCreationLaunch(
          model,
          CloneCreationStart.existingCandidate,
        ),
      );
    } else {
      await _admit(model, reuse: true);
    }
  }

  void cancelReauthentication() {
    if (!_blocked) state = state.copy(confirmReauthentication: false);
  }

  Future<void> confirmReauthentication() async {
    if (_blocked || !state.confirmReauthentication || state.selected == null) {
      return;
    }
    final selected = state.selected!;
    state = state.copy(confirmReauthentication: false);
    final model = await _refresh(selected);
    if (!mounted || model == null) return;
    state = state.copy(selected: model);
    await _admit(model, reuse: false);
  }

  Future<CloneCreationModel?> _refresh(CloneCreationModel previous) async {
    state = state.copy(
      busy: true,
      error: '',
      entitlementDenied: false,
      entitlementUnknown: false,
    );
    try {
      final models = await port.models();
      if (!mounted) return null;
      state = state.copy(models: models, busy: false);
      final matches = models.where((m) => m.id == previous.id);
      if (matches.length == 1) {
        final entitlement = cloneEntitlement(matches.single);
        if (entitlement != CloneEntitlement.allowed) {
          state = state.copy(
            entitlementDenied: entitlement == CloneEntitlement.denied,
            entitlementUnknown: entitlement == CloneEntitlement.unknown,
            error: entitlement == CloneEntitlement.unknown
                ? cloneEntitlementUnavailable
                : '',
          );
          return null;
        }
      }
      if (matches.length != 1 || !matches.single.available) {
        final reason = matches.length == 1
            ? matches.single.unavailableReason.trim()
            : '';
        state = state.copy(
          error: reason.isEmpty ? '当前模型暂不可用，请选择其他模型或稍后重试' : reason,
        );
        return null;
      }
      final model = matches.single;
      final paidEntry =
          model.requiresReauthentication ||
          !model.hasCandidate ||
          model.candidateFailed;
      if (paidEntry && model.pricePoints != previous.pricePoints) {
        state = state.copy(selected: model, error: '克隆价格已更新，请重新选择模型确认');
        return null;
      }
      return model;
    } catch (error) {
      if (mounted) {
        state = state.copy(
          busy: false,
          error: error is CloneCatalogFailure
              ? error.message
              : CloneCatalogFailure.serviceUnavailable.message,
        );
      }
      return null;
    }
  }

  Future<void> _admit(CloneCreationModel model, {required bool reuse}) async {
    state = state.copy(busy: true);
    try {
      final price = model.pricePoints;
      if (price == null || price <= 0) {
        state = state.copy(busy: false, error: cloneAdmissionError(price, 0));
        return;
      }
      final points = await port.availablePoints();
      if (!mounted) return;
      final error = cloneAdmissionError(price, points);
      if (error != null) {
        state = state.copy(busy: false, error: error);
        return;
      }
      final recording = reuse && await port.hasValidRecording();
      if (!mounted) return;
      state = state.copy(
        busy: false,
        launch: CloneCreationLaunch(
          model,
          recording
              ? CloneCreationStart.savedRecording
              : CloneCreationStart.authentication,
        ),
      );
    } catch (_) {
      if (mounted) state = state.copy(busy: false, error: '暂时无法检查克隆条件，请稍后重试');
    }
  }
}
