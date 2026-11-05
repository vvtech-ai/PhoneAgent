import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/sip/domestic_provider_catalog.dart';

class DomesticTranslationSettingsState {
  const DomesticTranslationSettingsState({
    this.catalog,
    this.loading = false,
    this.switching = false,
    this.error = '',
  });
  final DomesticProviderCatalog? catalog;
  final bool loading, switching;
  final String error;
  bool get ready => catalog != null;
  bool get busy => loading || switching;
  DomesticTranslationSettingsState copy({
    DomesticProviderCatalog? catalog,
    bool? loading,
    bool? switching,
    String? error,
  }) => DomesticTranslationSettingsState(
    catalog: catalog ?? this.catalog,
    loading: loading ?? this.loading,
    switching: switching ?? this.switching,
    error: error ?? this.error,
  );
}

/// Model settings belong to the current account lifetime.
class DomesticTranslationSettingsController
    extends StateNotifier<DomesticTranslationSettingsState> {
  DomesticTranslationSettingsController({
    required this.repository,
    required this.isCurrent,
  }) : super(const DomesticTranslationSettingsState());
  final DomesticProviderRepository repository;
  final bool Function() isCurrent;
  bool get _current => mounted && isCurrent();
  Future<void> load() async {
    if (!_current || state.busy) {
      return;
    }
    state = state.copy(loading: true, error: '');
    try {
      final catalog = await repository.load();
      if (_current) {
        state = state.copy(catalog: catalog, loading: false);
      }
    } catch (_) {
      if (_current) {
        state = state.copy(loading: false, error: '读取翻译模型失败，请重试');
      }
    }
  }

  Future<void> selectModel(String wireId) async {
    if (!_current || !state.ready || state.busy) {
      return;
    }
    final options = state.catalog!.options.where((v) => v.wireId == wireId);
    if (options.isEmpty || !options.first.available || options.first.active) {
      return;
    }
    state = state.copy(switching: true, error: '');
    try {
      final catalog = await repository.select(wireId);
      if (_current) {
        state = state.copy(catalog: catalog, switching: false);
      }
    } catch (_) {
      if (_current) {
        state = state.copy(switching: false, error: '翻译通话模型切换失败');
      }
    }
  }
}
