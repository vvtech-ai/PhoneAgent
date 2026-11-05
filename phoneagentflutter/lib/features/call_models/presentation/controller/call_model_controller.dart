import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/call_models.dart';
import '../../domain/clone_voice.dart';

class CallModelState {
  const CallModelState({
    this.catalog,
    this.loading = false,
    this.saving = false,
    this.error = '',
    this.voiceProvider,
    this.voices,
    this.voiceLoading = false,
    this.voiceSaving = false,
    this.voiceError = '',
    this.clone,
    this.cloneLoading = false,
    this.cloneNeedsRefresh = false,
    this.cloneError = '',
  });
  final CallModelCatalog? catalog;
  final bool loading, saving, voiceLoading, voiceSaving;
  final String error, voiceError;
  final String? voiceProvider;
  final CallVoiceCatalog? voices;
  final CloneVoiceSnapshot? clone;
  final bool cloneLoading, cloneNeedsRefresh;
  final String cloneError;

  CallModel? get voiceModel {
    for (final model in catalog?.models ?? const <CallModel>[]) {
      if (normalizeProvider(model.id) ==
          normalizeProvider(voiceProvider ?? '')) {
        return model;
      }
    }
    return null;
  }

  String get cloneProvider =>
      voiceModel?.capabilityProvider ?? voiceProvider ?? '';
  String get voiceModelName => voiceModel?.name.isNotEmpty == true
      ? voiceModel!.name
      : modelName(voiceProvider ?? '', '');
  bool get canUseVoiceModel =>
      !loading && !saving && voiceModel?.available == true;

  bool get canDeleteClone =>
      voiceProvider != null &&
      supportsCloneVoice(cloneProvider) &&
      normalizeProvider(clone?.modelId ?? '') ==
          normalizeProvider(cloneProvider) &&
      clone?.currentReady == true &&
      clone?.candidateReady != true &&
      !loading &&
      !saving &&
      !voiceLoading &&
      !voiceSaving &&
      !cloneLoading &&
      !cloneNeedsRefresh &&
      cloneError.isEmpty &&
      voiceError.isEmpty;

  CallModelState copy({
    CallModelCatalog? catalog,
    bool clearCatalog = false,
    bool? loading,
    bool? saving,
    String? error,
    String? voiceProvider,
    CallVoiceCatalog? voices,
    bool clearVoices = false,
    bool? voiceLoading,
    bool? voiceSaving,
    String? voiceError,
    CloneVoiceSnapshot? clone,
    bool? cloneLoading,
    bool? cloneNeedsRefresh,
    String? cloneError,
  }) => CallModelState(
    catalog: clearCatalog ? null : catalog ?? this.catalog,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: error ?? this.error,
    voiceProvider: voiceProvider ?? this.voiceProvider,
    voices: clearVoices ? null : voices ?? this.voices,
    voiceLoading: voiceLoading ?? this.voiceLoading,
    voiceSaving: voiceSaving ?? this.voiceSaving,
    voiceError: voiceError ?? this.voiceError,
    clone: clearVoices ? null : clone ?? this.clone,
    cloneLoading: cloneLoading ?? this.cloneLoading,
    cloneNeedsRefresh: cloneNeedsRefresh ?? this.cloneNeedsRefresh,
    cloneError: cloneError ?? this.cloneError,
  );
}

class CallModelController extends StateNotifier<CallModelState> {
  CallModelController(this._repository, {CloneVoiceRepository? cloneRepository})
    : _cloneRepository = cloneRepository,
      super(const CallModelState());
  final CallModelRepository _repository;
  final CloneVoiceRepository? _cloneRepository;
  int _catalogGeneration = 0, _voiceGeneration = 0;
  bool _refreshAfterSave = false;

  Future<void> load() async {
    if (state.saving) {
      _refreshAfterSave = true;
      state = state.copy(loading: true, clearCatalog: true);
      return;
    }
    final generation = ++_catalogGeneration;
    state = state.copy(loading: true, clearCatalog: true, error: '');
    try {
      final catalog = await _repository.load();
      if (mounted && generation == _catalogGeneration) {
        state = state.copy(catalog: catalog, loading: false);
      }
    } catch (_) {
      if (mounted && generation == _catalogGeneration) {
        state = state.copy(loading: false, error: '模型加载失败，请重试');
      }
    }
  }

  Future<bool> select(CallModel model) async {
    final current = state.catalog?.models
        .where(
          (item) => normalizeProvider(item.id) == normalizeProvider(model.id),
        )
        .firstOrNull;
    if (current?.available != true ||
        state.loading ||
        state.saving ||
        state.voiceSaving) {
      return false;
    }
    if (normalizeProvider(state.catalog?.activeProvider ?? '') ==
        normalizeProvider(model.id)) {
      return true;
    }
    ++_catalogGeneration;
    ++_voiceGeneration;
    state = state.copy(
      saving: true,
      loading: false,
      error: '',
      clearVoices: true,
      voiceLoading: false,
      cloneLoading: false,
      cloneNeedsRefresh: false,
      cloneError: '',
    );
    try {
      final catalog = await _repository.select(model.id);
      if (!mounted) return false;
      state = state.copy(catalog: catalog, saving: false);
    } catch (_) {
      if (mounted) state = state.copy(saving: false, error: '切换失败，已保留原模型');
      return false;
    } finally {
      if (mounted && _refreshAfterSave) {
        _refreshAfterSave = false;
        await load();
      }
    }
    return mounted &&
        normalizeProvider(state.catalog?.current?.id ?? '') ==
            normalizeProvider(model.id);
  }

  Future<void> loadVoices(String provider) async {
    if (state.voiceSaving || state.saving) return;
    final generation = ++_voiceGeneration;
    state = state.copy(
      voiceProvider: provider,
      clearVoices: state.voiceProvider != provider,
      voiceLoading: true,
      voiceError: '',
      cloneError: '',
    );
    final cloneLoad = _loadClone(provider, generation);
    try {
      final voices = await _repository.loadVoices(provider);
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(voices: voices, voiceLoading: false);
      }
    } catch (_) {
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(voiceLoading: false, voiceError: '音色加载失败，请重试');
      }
    } finally {
      await cloneLoad;
      if (mounted &&
          generation == _voiceGeneration &&
          state.voiceError.isEmpty &&
          state.cloneError.isEmpty) {
        state = state.copy(cloneNeedsRefresh: false);
      }
    }
  }

  Future<void> _loadClone(String provider, int generation) async {
    final cloneProvider = state.cloneProvider;
    if (!supportsCloneVoice(cloneProvider)) {
      state = state.copy(cloneLoading: false);
      return;
    }
    state = state.copy(cloneLoading: true);
    try {
      final repository = _cloneRepository;
      if (repository == null) throw StateError('Clone repository unavailable');
      final clone = await repository.load(cloneProvider);
      if (normalizeProvider(clone.modelId) !=
          normalizeProvider(cloneProvider)) {
        throw StateError('Clone model mismatch');
      }
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(clone: clone, cloneLoading: false);
      }
    } catch (_) {
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(cloneLoading: false, cloneError: '克隆音色读取失败，请重试');
      }
    }
  }

  Future<void> selectClone() async {
    final provider = state.voiceProvider, clone = state.clone;
    final repository = _cloneRepository;
    if (provider == null ||
        !state.canUseVoiceModel ||
        repository == null ||
        clone?.canSelect != true ||
        normalizeProvider(clone!.modelId) !=
            normalizeProvider(state.cloneProvider) ||
        state.voiceLoading ||
        state.cloneLoading ||
        state.cloneNeedsRefresh ||
        state.cloneError.isNotEmpty ||
        state.voiceError.isNotEmpty ||
        state.voiceSaving ||
        state.saving) {
      return;
    }
    if (!clone.candidateReady &&
        state.voices?.selectionMode.toUpperCase() == 'CLONE') {
      return;
    }
    final generation = ++_voiceGeneration;
    state = state.copy(voiceSaving: true, cloneError: '');
    try {
      if (clone.candidateReady) {
        await repository.confirmCandidate(state.cloneProvider);
      } else {
        final voices = await repository.selectConfirmed(provider);
        if (mounted && generation == _voiceGeneration) {
          state = state.copy(voices: voices);
        }
      }
      if (!mounted || generation != _voiceGeneration) return;
      state = state.copy(voiceSaving: false, cloneNeedsRefresh: true);
      await loadVoices(provider);
      if (mounted && generation + 1 == _voiceGeneration) await load();
    } catch (_) {
      if (mounted && generation == _voiceGeneration) {
        // The server may have accepted a timed-out write. Reconcile first,
        // never automatically replay a candidate confirmation.
        state = state.copy(
          voiceSaving: false,
          cloneNeedsRefresh: true,
          cloneError: '选择结果尚未同步，请刷新状态后再操作',
        );
      }
    }
  }

  /// The dialog captures a model id; never apply its late result to another model.
  Future<void> deleteClone(String expectedProvider) async {
    if (!mounted || !state.canDeleteClone) return;
    final provider = state.voiceProvider!;
    if (normalizeProvider(provider) != normalizeProvider(expectedProvider)) {
      return;
    }
    final repository = _cloneRepository;
    if (repository is! CloneVoiceDeletionPort) return;
    final generation = ++_voiceGeneration;
    state = state.copy(voiceSaving: true, cloneError: '');
    try {
      await (repository as CloneVoiceDeletionPort).deleteConfirmed(
        state.cloneProvider,
      );
      if (!mounted || generation != _voiceGeneration) return;
      state = state.copy(voiceSaving: false, cloneNeedsRefresh: true);
      await loadVoices(provider);
      if (mounted && generation + 1 == _voiceGeneration) await load();
    } catch (_) {
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(
          voiceSaving: false,
          cloneNeedsRefresh: true,
          cloneError: '删除结果尚未同步，请刷新状态后再操作',
        );
      }
    }
  }

  Future<void> selectVoice(CallVoice voice) async {
    final provider = state.voiceProvider;
    if (provider == null ||
        !state.canUseVoiceModel ||
        state.voiceLoading ||
        state.voiceSaving ||
        state.cloneNeedsRefresh ||
        state.saving) {
      return;
    }
    if (state.voices?.selectionMode == 'AI' &&
        state.voices?.activeVoice == voice.id) {
      return;
    }
    final generation = _voiceGeneration;
    state = state.copy(voiceSaving: true, voiceError: '');
    try {
      final voices = await _repository.selectVoice(provider, voice.id);
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(voices: voices, voiceSaving: false);
        await load();
      }
    } catch (_) {
      if (mounted && generation == _voiceGeneration) {
        state = state.copy(
          voiceSaving: false,
          cloneNeedsRefresh: true,
          voiceError: '音色设置尚未同步，请刷新状态后再操作',
        );
      }
    }
  }
}
