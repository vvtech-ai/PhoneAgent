import 'dart:async';
import '../../domain/apology_voice.dart';

/// Task-scoped consent and voice selection; never writes a global voice setting.
class ApologyVoiceController {
  ApologyVoiceController({
    required this.port,
    required this.currentModel,
    required this.currentModelName,
    this.modelNameFor,
    required this.isCurrent,
    required this.present,
    this.onChoice,
    this.onQueryStart,
    required this.interrupt,
    required this.cancelTask,
    required this.resume,
  });
  final ApologyVoicePort? port;
  final String Function() currentModel, currentModelName;
  final String Function(String)? modelNameFor;
  final bool Function() isCurrent;
  final void Function(ApologyPrompt) present;
  final void Function(ApologyPrompt, int)? onChoice;
  final void Function()? onQueryStart;
  final void Function() interrupt;
  final Future<void> Function() cancelTask;
  final void Function(String) resume;
  ApologyVoiceStage stage = ApologyVoiceStage.consent;
  ApologyVoice? selection, _pending;
  ApologyPrompt? prompt;
  int _generation = 0, _promptId = 0;
  bool _closed = false;
  bool _changed = false;
  String? _selectionSummary;
  String? _model;
  void Function()? _input;
  bool get blocked => stage != ApologyVoiceStage.ready;
  bool get _current => !_closed && isCurrent();
  void submitted() => prompt = null;
  void restore(String modelId) {
    _model = modelId;
    _selectionSummary = null;
    stage = ApologyVoiceStage.ready;
    prompt = null;
  }

  String? get modelId => selection?.modelId ?? _model;

  /// The user-visible record produced by an explicit model switch.  The
  /// conversation binding uses this as the opening text so the choice is
  /// retained by the existing durable assistant-turn contract.
  String? get selectionSummary => _selectionSummary;

  String modelName(String id) =>
      modelNameFor?.call(id) ??
      (id == currentModel() ? currentModelName() : id);

  void begin() => _show(ApologyVoicePolicy.consent, [
    ApologyVoicePolicy.confirm,
    ApologyVoicePolicy.decline,
  ]);
  void _show(
    String text,
    List<ApologyChoice> choices, {
    bool modelChoice = false,
  }) {
    if (!_current) return;
    prompt = ApologyPrompt(
      'apology:${++_promptId}',
      text,
      choices,
      modelChoice: modelChoice,
    );
    present(prompt!);
  }

  bool input(String text, {void Function()? afterConsent}) {
    if (!blocked) return false;
    if (!_current) return true;
    if (stage == ApologyVoiceStage.checking) return true;
    final id = ApologyVoicePolicy.textChoice(text, prompt?.choices ?? []);
    if (id != null) {
      choose(id);
    } else if (stage != ApologyVoiceStage.stopped && text.length > 4) {
      _input = afterConsent ?? () => resume(text);
    }
    return true;
  }

  void choose(String id) {
    if (!_current || !(prompt?.choices.any((c) => c.id == id) ?? false)) return;
    final chosenPrompt = prompt!;
    onChoice?.call(
      chosenPrompt,
      chosenPrompt.choices.indexWhere((choice) => choice.id == id),
    );
    prompt = null;
    interrupt();
    if (id == 'decline' || id == 'retry_cancel') {
      unawaited(_stop());
    } else if (id.startsWith('model:')) {
      unawaited(_query(id.substring(6), changing: true));
    } else {
      unawaited(
        _query(
          _model ?? currentModel(),
          confirmed: stage == ApologyVoiceStage.modelConsent
              ? _pending?.assetId
              : null,
        ),
      );
    }
  }

  void modelChanged(String model) {
    if (!_current ||
        model.isEmpty ||
        stage == ApologyVoiceStage.consent ||
        stage == ApologyVoiceStage.stopped ||
        model == _model) {
      return;
    }
    interrupt();
    unawaited(_query(model, changing: true));
  }

  void modelUnavailable() {
    if (!_current ||
        stage == ApologyVoiceStage.consent ||
        stage == ApologyVoiceStage.stopped ||
        stage == ApologyVoiceStage.needsVoice && _model == null) {
      return;
    }
    ++_generation;
    selection = null;
    _model = null;
    _pending = null;
    _input = null;
    stage = ApologyVoiceStage.needsVoice;
    interrupt();
    _show('当前会员暂无可用通话模型，请刷新模型列表或调整会员权益后重试。', [ApologyVoicePolicy.decline]);
  }

  Future<void> _query(
    String model, {
    String? confirmed,
    bool changing = false,
  }) async {
    final generation = ++_generation;
    bool valid() => _current && generation == _generation;
    _selectionSummary = null;
    _model = model;
    _changed = _changed || changing;
    selection = null;
    stage = ApologyVoiceStage.checking;
    prompt = null;
    onQueryStart?.call();
    try {
      final service = port;
      if (service == null) throw StateError('Voice service unavailable');
      var voices = await service.voices();
      if (!valid()) return;
      var voice = voices.where((v) => v.modelId == model).firstOrNull;
      if (voice?.candidate == true && voice!.assetId == confirmed) {
        await service.confirmCandidate(voice);
        if (!valid()) return;
        voices = await service.voices();
        if (!valid()) return;
        voice = voices
            .where(
              (v) =>
                  v.modelId == model && !v.candidate && v.assetId == confirmed,
            )
            .firstOrNull;
        if (voice == null && voices.any((v) => v.modelId == model)) {
          throw StateError('Voice confirmation not visible');
        }
      }
      _pending = voice;
      if (voice == null) {
        stage = ApologyVoiceStage.needsVoice;
        final others = voices.where((v) => v.modelId != model).toList();
        final name = modelNameFor?.call(model) ?? currentModelName();
        _show(
          others.isEmpty
              ? '$name没有您的可用克隆音色，请先前往设置中的“声音克隆”完成克隆，或不使用。'
              : '$name没有您的可用克隆音色，请选择以下已有克隆音色的模型，或不使用。',
          [
            ...others.map((v) => ApologyChoice('model:${v.modelId}', v.name)),
            ApologyVoicePolicy.decline,
          ],
          modelChoice: others.isNotEmpty,
        );
      } else if (voice.candidate ||
          _changed && !voice.active && voice.assetId != confirmed) {
        stage = ApologyVoiceStage.modelConsent;
        _show('${voice.name} 已有您的克隆音色，是否用于本次电话？确认后仅本次电话使用，不修改该模型的默认音色。', [
          ApologyVoicePolicy.confirm,
          ApologyVoicePolicy.decline,
        ]);
      } else {
        selection = voice;
        stage = ApologyVoiceStage.ready;
        final summary = _changed
            ? '已切换为${voice.name}，本次电话使用您的克隆音色。请继续当前道歉对话。'
            : null;
        _selectionSummary = summary;
        _show(summary ?? ApologyVoicePolicy.ready, []);
        _changed = false;
        final pending = _input;
        _input = null;
        if (pending != null && valid()) pending();
      }
    } catch (_) {
      if (!valid()) return;
      stage = ApologyVoiceStage.needsVoice;
      _show('暂时无法查询或确认您的克隆音色，请重试。', [
        ApologyVoicePolicy.retry,
        ApologyVoicePolicy.decline,
      ]);
    }
  }

  Future<void> _stop() async {
    final generation = ++_generation;
    selection = null;
    _selectionSummary = null;
    _pending = null;
    _input = null;
    stage = ApologyVoiceStage.stopped;
    _show('正在取消本次道歉任务…', []);
    try {
      await cancelTask();
      if (_current && generation == _generation) _show('好的，已停止本次道歉任务。', []);
    } catch (_) {
      if (_current && generation == _generation) {
        _show('取消请求未完成，请重试。确认取消前，本次任务不会拨号。', [
          const ApologyChoice('retry_cancel', '重试取消'),
        ]);
      }
    }
  }

  void close() {
    _closed = true;
    ++_generation;
    selection = null;
    _selectionSummary = null;
    _input = null;
  }
}
