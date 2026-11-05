import 'package:phone_agent/features/home/domain/home_defaults.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
// Shared by the debug Web workbench and VM tests. No test-framework dependency.
import 'package:phone_agent/features/call_models/domain/call_models.dart';

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({this.translationEnabled = false});
  final bool translationEnabled;
  int loads = 0, rotations = 0;
  @override
  Future<HomeConfig> load() async {
    loads++;
    if (!translationEnabled) return builtinHome;
    return HomeConfig(builtinHome.version, builtinHome.slogans, [
      for (final card in builtinHome.cards)
        if (card.action == HomeAction.translation)
          HomeCard(
            id: card.id,
            title: card.title,
            subtitle: 'MOCK · 配置到通话交互，无真实外呼',
            status: HomeCardStatus.enabled,
            action: card.action,
            skillId: card.skillId,
          )
        else
          card,
    ], builtin: true);
  }

  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async {
    rotations++;
    return config.slogans.first;
  }
}

class FakeCallModelRepository implements CallModelRepository {
  FakeCallModelRepository({
    this.includeCloneModels = false,
    this.nativeSystemVoices = false,
    this.doubaoSupportsVoiceClone,
  }) {
    if (nativeSystemVoices) voice = 'Andre';
  }
  final bool includeCloneModels, nativeSystemVoices;
  final bool? doubaoSupportsVoiceClone;
  final cloneAssets = <String>{}, cloneModes = <String>{};
  String provider = 'QWEN_OMNI_PLUS', voice = 'v1';
  bool fail = false;
  int saves = 0;
  CallModelCatalog get catalog => CallModelCatalog(provider, [
    CallModel(
      id: 'QWEN_OMNI_PLUS',
      name: 'QwenOmniPlus',
      description: '测试模型一',
      available: true,
      active: provider == 'QWEN_OMNI_PLUS',
      multiplier: 1,
    ),
    CallModel(
      id: 'DOUBAO',
      name: 'Seeduplex',
      description: '测试模型二',
      available: true,
      active: provider == 'DOUBAO',
      multiplier: 2,
      supportsVoiceClone: doubaoSupportsVoiceClone,
    ),
    if (includeCloneModels)
      CallModel(
        id: 'DOUBAO_SEEDUPLEX_3_0',
        name: 'Seeduplex V3',
        description: '合成克隆模型',
        available: true,
        active: provider == 'DOUBAO_SEEDUPLEX_3_0',
      ),
  ]);
  @override
  Future<CallModelCatalog> load() async => catalog;
  @override
  Future<CallModelCatalog> select(String provider) async {
    if (fail) throw StateError('synthetic');
    saves++;
    this.provider = provider;
    return catalog;
  }

  List<CallVoice> _voices(String provider) => !nativeSystemVoices
      ? const [
          CallVoice('v1', '音色一', '清朗男声', true),
          CallVoice('v2', '音色二', '职业女声', false),
        ]
      : provider.startsWith('DOUBAO')
      ? const [
          CallVoice(
            'zh_male_xiaotian_jupiter_bigtts',
            '清朗男声',
            '合成目录 · 本地样音',
            true,
          ),
          CallVoice('S_1C6XHhfZ1', '沉稳男声', '合成目录 · 本地样音', false),
        ]
      : const [
          CallVoice('Andre', 'Andre', '合成目录 · 本地样音', true),
          CallVoice('Ethan', 'Ethan', '合成目录 · 本地样音', false),
          CallVoice('Katerina', 'Katerina', '合成目录 · 本地样音', false),
        ];
  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async {
    final choices = _voices(provider);
    return CallVoiceCatalog(
      choices.any((entry) => entry.id == voice) ? voice : choices.first.id,
      cloneModes.contains(provider) ? 'CLONE' : 'AI',
      choices,
    );
  }

  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) async {
    if (fail) throw StateError('synthetic');
    saves++;
    this.voice = voice;
    cloneModes.remove(provider);
    return loadVoices(provider);
  }
}
