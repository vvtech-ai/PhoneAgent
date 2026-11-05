import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/model_voice_summary.dart';

CallModel model(String id, [String label = '']) => CallModel(
  id: id,
  name: '合成模型',
  description: '',
  available: true,
  active: true,
  voiceName: label,
);

void main() {
  test('updated inactive model clone selection precedes stale snapshot', () {
    expect(
      modelVoiceSummary(
        model('QWEN_OMNI_PLUS', 'Andre'),
        activeProvider: 'DOUBAO',
        voiceProvider: 'QWEN_OMNI_PLUS',
        voices: const CallVoiceCatalog('', 'CLONE', []),
      ),
      '我的克隆音色',
    );
  });

  test('supported defaults and server labels are display facts only', () {
    for (final id in ['QWEN_OMNI_PLUS', 'QWEN_OMNI_FLASH']) {
      expect(modelVoiceSummary(model(id), activeProvider: id), 'Andre');
    }
    for (final id in ['DOUBAO', 'DOUBAO_SEEDUPLEX_3_0']) {
      expect(modelVoiceSummary(model(id), activeProvider: id), '清朗男声');
    }
    expect(modelVoiceSummary(model('FUTURE'), activeProvider: 'FUTURE'), '');
    expect(
      modelVoiceSummary(model('FUTURE', '合成音色'), activeProvider: 'FUTURE'),
      '合成音色',
    );
  });
  test('matching authoritative voice response precedes snapshot', () {
    const voices = CallVoiceCatalog('Ethan', 'AI', [
      CallVoice('Ethan', 'Ethan', '', false),
    ]);
    expect(
      modelVoiceSummary(
        model('QWEN_OMNI_PLUS', 'Andre'),
        activeProvider: 'QWEN_OMNI_PLUS',
        voiceProvider: 'QWEN_OMNI_PLUS',
        voices: voices,
      ),
      'Ethan',
    );
    expect(
      modelVoiceSummary(
        model('DOUBAO'),
        activeProvider: 'QWEN_OMNI_PLUS',
        voiceProvider: 'QWEN_OMNI_PLUS',
        voices: voices,
      ),
      '清朗男声',
    );
    expect(
      modelVoiceSummary(
        model('QWEN_OMNI_PLUS'),
        activeProvider: 'QWEN_OMNI_PLUS',
        voiceProvider: 'DOUBAO',
        voices: voices,
      ),
      'Andre',
    );
  });
  test('native friendly voice ids and absent catalog name', () {
    for (final item in {
      'zh_male_xiaotian_jupiter_bigtts': '清朗男声',
      'S_1C6XHhfZ1': '沉稳男声',
      'synthetic': 'synthetic',
    }.entries) {
      expect(
        modelVoiceSummary(
          model('DOUBAO'),
          activeProvider: 'DOUBAO',
          voiceProvider: 'DOUBAO',
          voices: CallVoiceCatalog(item.key, 'AI', const []),
        ),
        item.value,
      );
    }
  });
  test('clone response is authoritative; candidate alone is not selection', () {
    final m = model('QWEN_OMNI_PLUS', '我的克隆音色');
    expect(
      modelVoiceSummary(
        m,
        activeProvider: m.id,
        unconfirmedCloneCandidate: true,
      ),
      'Andre',
    );
    expect(
      modelVoiceSummary(
        m,
        activeProvider: m.id,
        voiceProvider: m.id,
        voices: const CallVoiceCatalog('', 'CLONE', []),
        unconfirmedCloneCandidate: true,
      ),
      '我的克隆音色',
    );
    expect(
      modelVoiceSummary(
        m,
        activeProvider: 'DOUBAO',
        unconfirmedCloneCandidate: true,
      ),
      '我的克隆音色',
    );
  });
}
