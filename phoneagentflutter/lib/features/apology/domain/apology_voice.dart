class ApologyVoice {
  const ApologyVoice(
    this.modelId,
    this.name,
    this.assetId, {
    this.candidate = false,
    this.active = false,
  });
  final String modelId, name, assetId;
  final bool candidate, active;
  Map<String, Object?> get selection => {
    'modelId': modelId,
    'providerAssetId': assetId,
  };
}

abstract interface class ApologyVoicePort {
  Future<List<ApologyVoice>> voices();
  Future<void> confirmCandidate(ApologyVoice voice);
}

enum ApologyVoiceStage {
  consent,
  checking,
  needsVoice,
  modelConsent,
  ready,
  stopped,
}

class ApologyChoice {
  const ApologyChoice(this.id, this.label);
  final String id, label;
}

class ApologyPrompt {
  const ApologyPrompt(
    this.id,
    this.text,
    this.choices, {
    this.modelChoice = false,
  });
  final String id, text;
  final List<ApologyChoice> choices;
  final bool modelChoice;
}

abstract final class ApologyVoicePolicy {
  static const skillId = 'apology_master';
  static const consent = '我来代替你打电话给熟人道歉。道歉需要使用您的克隆音色，确认使用吗？';
  static const ready = '好的，使用您的克隆音色。您想向谁道歉？发生了什么事？';
  static const confirm = ApologyChoice('confirm', '确认使用');
  static const decline = ApologyChoice('decline', '不使用');
  static const retry = ApologyChoice('retry', '重试');

  static String? textChoice(String raw, List<ApologyChoice> choices) {
    final text = raw.trim().replaceAll(RegExp(r'[，。！？,.!?\s]'), '');
    for (final choice in choices) {
      if (choice.label == text) return choice.id;
    }
    final ordinal = RegExp(
      r'^(?:选择|选)?(?:第)?([123一二三])(?:个|项)?$',
    ).firstMatch(text);
    if (ordinal != null) {
      final index =
          const ['1', '2', '3', '一', '二', '三'].indexOf(ordinal[1]!) % 3;
      if (index < choices.length) return choices[index].id;
    }
    final id = switch (text) {
      '同意' || '确认' || '是的' || '同意使用' || '确认使用克隆音色' || '使用我的声音' => 'confirm',
      '不同意' ||
      '不确认' ||
      '确认不使用' ||
      '拒绝' ||
      '取消' ||
      '不要' ||
      '不用' ||
      '暂时不用' ||
      '暂不使用' => 'decline',
      '重试' || '重新查询' => 'retry',
      _ => null,
    };
    return choices.any((c) => c.id == id) ? id : null;
  }
}
