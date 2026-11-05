import '../../call_models/domain/call_models.dart';
import '../../call_models/domain/clone_voice.dart';

/// Model-scoped synthetic assets. Never connected to account/network/storage.
class PreviewCloneManagementRepository implements CallModelRepository {
  PreviewCloneManagementRepository({
    this.failFirstDelete = false,
    this.failReadAfterDelete = false,
    this.candidate = false,
  });
  final bool failFirstDelete, failReadAfterDelete, candidate;
  String active = 'QWEN_OMNI_PLUS';
  static const names = {
    'QWEN_OMNI_PLUS': 'QwenOmniPlus',
    'DOUBAO_SEEDUPLEX_3_0': 'Seeduplex V3',
  };
  final assets = <String>{...names.keys};
  final modes = {for (final id in names.keys) id: 'CLONE'};
  final deleted = <String>[];
  bool _failed = false, _readFailure = false;
  @override
  Future<CallModelCatalog> load() async => CallModelCatalog(active, [
    for (final entry in names.entries)
      CallModel(
        id: entry.key,
        name: entry.value,
        description: '合成克隆模型，不修改当前账号',
        available: true,
        active: active == entry.key,
        voiceName: modes[entry.key] == 'CLONE' ? '合成克隆音色' : '合成系统音色',
      ),
  ]);
  @override
  Future<CallModelCatalog> select(String provider) async {
    active = provider;
    return load();
  }

  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async {
    if (_readFailure) {
      _readFailure = false;
      throw StateError('Synthetic read failure');
    }
    return CallVoiceCatalog('system', modes[provider]!, const [
      CallVoice('system', '合成系统音色', '演练，不播放声音', true),
    ]);
  }

  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) async {
    modes[provider] = 'AI';
    return loadVoices(provider);
  }

  Future<void> delete(String provider) async {
    deleted.add(provider);
    if (failFirstDelete && !_failed) {
      _failed = true;
      throw StateError('Synthetic delete failure');
    }
    assets.remove(provider);
    modes[provider] = 'AI';
    _readFailure = failReadAfterDelete;
  }
}

class PreviewCloneManagementPort
    implements CloneVoiceRepository, CloneVoiceDeletionPort {
  PreviewCloneManagementPort(this.repository);
  final PreviewCloneManagementRepository repository;
  @override
  Future<CloneVoiceSnapshot> load(String provider) async => CloneVoiceSnapshot(
    modelId: provider,
    available: true,
    currentStatus: repository.assets.contains(provider)
        ? 'READY'
        : 'NOT_CREATED',
    currentHasAsset: repository.assets.contains(provider),
    candidateStatus: repository.candidate ? 'READY' : '',
    candidateBillingStatus: repository.candidate ? 'CHARGED' : '',
  );
  @override
  Future<void> deleteConfirmed(String provider) => repository.delete(provider);
  @override
  Future<void> confirmCandidate(String provider) async {
    repository.modes[provider] = 'CLONE';
  }

  @override
  Future<CallVoiceCatalog> selectConfirmed(String provider) async {
    repository.modes[provider] = 'CLONE';
    return repository.loadVoices(provider);
  }
}
