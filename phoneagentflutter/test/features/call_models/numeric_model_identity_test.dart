import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_repository.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';

void main() {
  test(
    'numeric selection id retains provider, name and clone identity',
    () async {
      final catalog = ApiCallModelRepository.catalog({
        'activeModelId': '4',
        'providers': [
          {
            'modelId': '4',
            'provider': 'QWEN_OMNI_PLUS',
            'displayName': 'QwenOmniPlus',
            'supportsVoiceClone': true,
            'cloneModelId': '13',
            'available': true,
            'active': true,
          },
        ],
      });
      final clones = _Clones();
      final models = _Models(catalog);
      final controller = CallModelController(models, cloneRepository: clones);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.loadVoices('4');
      expect(controller.state.voiceModelName, 'QwenOmniPlus');
      expect(controller.state.voiceProvider, '4');
      expect(controller.state.cloneProvider, '4');
      expect(clones.requested, '4');
      expect(controller.state.canDeleteClone, isTrue);
      await controller.selectClone();
      expect(clones.selected, '4');
      expect(models.requested, '4');
    },
  );
  test('unknown numeric identity never guesses clone capability from name', () {
    const state = CallModelState(
      voiceProvider: '4',
      catalog: CallModelCatalog('4', [
        CallModel(
          id: '4',
          name: 'QwenOmniPlus',
          description: '',
          available: true,
          active: true,
          supportsVoiceClone: false,
        ),
      ]),
    );
    expect(state.voiceModelName, 'QwenOmniPlus');
    expect(supportsCloneVoice(state.cloneProvider), isFalse);
  });
}

class _Models implements CallModelRepository {
  _Models(this.catalog);
  final CallModelCatalog catalog;
  String? requested;
  @override
  Future<CallModelCatalog> load() async => catalog;
  @override
  Future<CallModelCatalog> select(String provider) async => catalog;
  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async {
    requested = provider;
    return const CallVoiceCatalog('Andre', 'AI', []);
  }

  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) =>
      loadVoices(provider);
}

class _Clones implements CloneVoiceRepository {
  String? requested, selected;
  @override
  Future<CloneVoiceSnapshot> load(String provider) async {
    requested = provider;
    return CloneVoiceSnapshot(
      modelId: provider,
      available: true,
      currentStatus: 'READY',
      currentHasAsset: true,
    );
  }

  @override
  Future<void> confirmCandidate(String provider) async {}
  @override
  Future<CallVoiceCatalog> selectConfirmed(String provider) async {
    selected = provider;
    return const CallVoiceCatalog('', 'CLONE', []);
  }
}
