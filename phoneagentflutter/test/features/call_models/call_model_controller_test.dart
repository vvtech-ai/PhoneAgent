import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_repository.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';

const models = [
  CallModel(
    id: 'QWEN_OMNI_PLUS',
    name: 'QwenOmniPlus',
    description: '',
    available: true,
    active: true,
  ),
  CallModel(
    id: 'DOUBAO',
    name: 'Seeduplex',
    description: '',
    available: true,
    active: false,
  ),
];
const catalog = CallModelCatalog('QWEN_OMNI_PLUS', models);
const voices = CallVoiceCatalog('v1', 'AI', [
  CallVoice('v1', '一', '', true),
  CallVoice('v2', '二', '', false),
]);

class _Repository implements CallModelRepository {
  bool fail = false;
  Completer<CallVoiceCatalog>? oldVoice;
  @override
  Future<CallModelCatalog> load() async => catalog;
  @override
  Future<CallModelCatalog> select(String provider) async {
    if (fail) throw StateError('synthetic failure');
    return CallModelCatalog(provider, []);
  }

  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async =>
      provider == 'old' ? oldVoice!.future : voices;
  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) async {
    if (fail) throw StateError('synthetic failure');
    return CallVoiceCatalog(voice, 'AI', voices.voices);
  }
}

void main() {
  test(
    'available not configured controls selection; alias and unknown price preserved',
    () {
      final result = ApiCallModelRepository.catalog({
        'activeProvider': 'QWEN_OMNI_FLASH',
        'providers': [
          {
            'provider': 'QWEN_OMNI_PLUS',
            'displayName': 'Qwen',
            'available': true,
            'configured': false,
            'billingMultiplier': -1,
          },
        ],
      });
      expect(result.current!.available, true);
      expect(result.current!.recommended, false);
      expect(result.current!.multiplier, isNull);
    },
  );
  test('failed model/voice saves retain old selections', () async {
    final repository = _Repository(),
        controller = CallModelController(_Repository());
    controller.dispose();
    final c = CallModelController(repository);
    await c.load();
    repository.fail = true;
    expect(await c.select(models[1]), false);
    expect(c.state.catalog!.activeProvider, 'QWEN_OMNI_PLUS');
    await c.loadVoices('QWEN_OMNI_PLUS');
    await c.selectVoice(voices.voices[1]);
    expect(c.state.voices!.activeVoice, 'v1');
    expect(c.state.voiceError, isNotEmpty);
    c.dispose();
  });
  test('late old voice response cannot replace current model voices', () async {
    final repository = _Repository()..oldVoice = Completer<CallVoiceCatalog>();
    final c = CallModelController(repository);
    final old = c.loadVoices('old');
    await c.loadVoices('new');
    repository.oldVoice!.complete(const CallVoiceCatalog('stale', 'AI', []));
    await old;
    expect(c.state.voiceProvider, 'new');
    expect(c.state.voices!.activeVoice, 'v1');
    c.dispose();
  });
}
