import '../../identity/domain/identity_profile.dart';
import '../domain/initialization_gateway.dart';

enum InitializationPreviewScenario {
  normal,
  loadFailure,
  callFailure,
  identityFailure,
  skipFailure,
  existingIdentity,
  alreadySkipped,
}

class PreviewInitializationGateway implements InitializationGateway {
  PreviewInitializationGateway(this.scenario);
  final InitializationPreviewScenario scenario;
  bool _failed = false, skipped = false;
  IdentityDraft? savedIdentity;
  String callModel = 'DOUBAO';
  final List<String> writes = [];
  void _fail(InitializationPreviewScenario candidate) {
    if (!_failed && scenario == candidate) {
      _failed = true;
      throw StateError('synthetic failure');
    }
  }

  @override
  Future<bool> isSkipped() async =>
      skipped || scenario == InitializationPreviewScenario.alreadySkipped;
  @override
  Future<IdentityProfile> loadIdentity() async {
    _fail(InitializationPreviewScenario.loadFailure);
    return IdentityProfile(
      accountId: 'mock-init',
      name: scenario == InitializationPreviewScenario.existingIdentity
          ? '合成资料'
          : '',
    );
  }

  @override
  Future<InitializationCatalog> loadCallModels() async =>
      InitializationCatalog(callModel, const [
        InitializationModel(
          'QWEN_OMNI_PLUS',
          'QwenOmniPlus',
          '支持系统音色和声音克隆',
          recommended: true,
        ),
        InitializationModel('DOUBAO', 'Seeduplex', '仅支持系统音色'),
        InitializationModel(
          'GPT',
          'GPT Realtime',
          '即将支持 · 演练禁用项',
          enabled: false,
        ),
      ]);
  @override
  Future<void> selectCallModel(String id) async {
    writes.add('call:$id');
    _fail(InitializationPreviewScenario.callFailure);
    callModel = id;
  }

  @override
  Future<void> saveIdentity(IdentityDraft draft) async {
    writes.add('identity');
    _fail(InitializationPreviewScenario.identityFailure);
    savedIdentity = draft;
  }

  @override
  Future<void> markSkipped() async {
    writes.add('skip');
    _fail(InitializationPreviewScenario.skipFailure);
    skipped = true;
  }
}
