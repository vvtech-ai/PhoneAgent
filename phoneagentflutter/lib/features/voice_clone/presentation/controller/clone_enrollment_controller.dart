import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/clone_enrollment.dart';
import '../../domain/clone_creation.dart';

class CloneEnrollmentState {
  const CloneEnrollmentState({
    this.step = CloneStep.consent,
    this.agreed = false,
    this.busy = false,
    this.replacement = false,
    this.saveRecording = true,
    this.playing = false,
    this.previewLoading = false,
    this.error = '',
    this.script = '',
    this.showSaveRecording = true,
  });
  final CloneStep step;
  final bool agreed, busy, replacement, saveRecording, playing, previewLoading;
  final String error, script;
  final bool showSaveRecording;
  CloneEnrollmentState copy({
    CloneStep? step,
    bool? agreed,
    bool? busy,
    bool? replacement,
    bool? saveRecording,
    bool? playing,
    bool? previewLoading,
    String? error,
    String? script,
    bool? showSaveRecording,
  }) => CloneEnrollmentState(
    step: step ?? this.step,
    agreed: agreed ?? this.agreed,
    busy: busy ?? this.busy,
    replacement: replacement ?? this.replacement,
    saveRecording: saveRecording ?? this.saveRecording,
    playing: playing ?? this.playing,
    previewLoading: previewLoading ?? this.previewLoading,
    error: error ?? this.error,
    script: script ?? this.script,
    showSaveRecording: showSaveRecording ?? this.showSaveRecording,
  );
}

class CloneEnrollmentController extends StateNotifier<CloneEnrollmentState> {
  CloneEnrollmentController(this.port, {this.reuseOnRerecord = false})
    : super(const CloneEnrollmentState());
  final CloneEnrollmentPort port;
  final bool reuseOnRerecord;
  CloneCreationStart _candidateStart = CloneCreationStart.savedRecording;
  bool _closed = false;
  int _generation = 0, _previewGeneration = 0;
  String _name = '', _identity = '';
  bool get exitBlocked => state.busy;
  bool get needsExitConfirmation =>
      state.step == CloneStep.candidate && state.showSaveRecording;

  Future<void> openCandidate(CloneCreationStart start) async {
    if (_closed || state.busy || start == CloneCreationStart.authentication) {
      return;
    }
    final candidatePort = port;
    if (candidatePort is! CloneCandidateEntryPort) return;
    _candidateStart = start;
    final generation = ++_generation;
    _stopPreview();
    state = state.copy(
      step: CloneStep.generating,
      busy: true,
      playing: false,
      showSaveRecording: false,
      saveRecording: false,
      error: '',
    );
    try {
      final ready = await (candidatePort as CloneCandidateEntryPort)
          .openCandidate(start);
      if (!_current(generation)) return;
      state = ready
          ? state.copy(step: CloneStep.candidate, busy: false)
          : const CloneEnrollmentState(error: '认证录音或身份已失效，请重新完成认证');
    } catch (_) {
      if (_current(generation)) {
        state = state.copy(
          step: CloneStep.candidateError,
          busy: false,
          error: '候选生成或读取未完成，尚未设为默认声音',
        );
      }
    }
  }

  Future<void> retryCandidate() async {
    if (!_closed && state.step == CloneStep.candidateError) {
      await openCandidate(_candidateStart);
    }
  }

  void agree(bool value) {
    if (!_closed && state.step == CloneStep.consent) {
      state = state.copy(agreed: value);
    }
  }

  void next() {
    if (!_closed && state.step == CloneStep.consent && state.agreed) {
      state = state.copy(step: CloneStep.identity);
    }
  }

  Future<void> submitIdentity(String name, String number) async {
    if (_closed ||
        state.busy ||
        state.step != CloneStep.identity ||
        state.replacement) {
      return;
    }
    _name = name.trim();
    _identity = number.trim().toUpperCase();
    if (_name.isEmpty || !validCloneIdentityNumber(_identity)) {
      state = state.copy(error: '请填写姓名和有效的18位身份证号');
      return;
    }
    final generation = ++_generation;
    state = state.copy(busy: true, error: '');
    try {
      final replace = await port.replacementRequired(_identity);
      if (!_current(generation)) return;
      if (replace) {
        state = state.copy(busy: false, replacement: true);
        return;
      }
      await _enroll(generation, false);
    } catch (_) {
      _identityFailure(generation);
    }
  }

  void cancelReplacement() {
    if (!_closed && state.replacement && !state.busy) {
      _name = '';
      _identity = '';
      state = state.copy(replacement: false);
    }
  }

  Future<void> confirmReplacement() async {
    if (_closed || !state.replacement || state.busy) return;
    final generation = ++_generation;
    state = state.copy(replacement: false, busy: true, error: '');
    try {
      await _enroll(generation, true);
    } catch (_) {
      _identityFailure(generation);
    }
  }

  Future<void> _enroll(int generation, bool replacement) async {
    final verification = await port.initialize(_name, _identity, replacement);
    // Clear sensitive form values as soon as handed to the port, never log them.
    _name = '';
    _identity = '';
    if (!_current(generation)) return;
    state = state.copy(step: CloneStep.collecting, script: verification.script);
    await port.collect(verification);
    if (!_current(generation)) return;
    state = state.copy(step: CloneStep.checking);
    await port.verify(verification);
    if (!_current(generation)) return;
    state = state.copy(step: CloneStep.generating);
    await port.generate(verification);
    if (!_current(generation)) return;
    state = state.copy(
      step: CloneStep.candidate,
      busy: false,
      saveRecording: true,
      showSaveRecording: true,
    );
  }

  void _identityFailure(int generation) {
    _name = '';
    _identity = '';
    if (_current(generation)) {
      state = state.copy(
        step: CloneStep.identity,
        busy: false,
        error: '认证或生成未完成，请重试；未设为默认声音',
      );
    }
  }

  void saveRecording(bool value) {
    if (!_closed &&
        !state.busy &&
        state.showSaveRecording &&
        state.step == CloneStep.candidate) {
      state = state.copy(saveRecording: value);
    }
  }

  Future<void> togglePreview() async {
    if (_closed || state.busy || state.step != CloneStep.candidate) return;
    final generation = ++_previewGeneration;
    if (state.playing) {
      port.stopPreview();
      state = state.copy(playing: false);
      return;
    }
    state = state.copy(playing: true, error: '');
    try {
      await port.preview();
      if (!_closed && generation == _previewGeneration) {
        state = state.copy(playing: false);
      }
    } catch (_) {
      if (!_closed && generation == _previewGeneration) {
        state = state.copy(playing: false, error: '试听失败，请重试');
      }
    }
  }

  void _stopPreview() {
    ++_previewGeneration;
    port.stopPreview();
  }

  Future<void> confirm() async {
    if (_closed || state.busy || state.step != CloneStep.candidate) return;
    final generation = ++_generation;
    _stopPreview();
    state = state.copy(busy: true, playing: false, error: '');
    try {
      await port.confirm(saveRecording: state.saveRecording);
      if (_current(generation)) {
        state = state.copy(step: CloneStep.confirmed, busy: false);
      }
    } catch (_) {
      if (_current(generation)) {
        state = state.copy(busy: false, error: '确认结果未同步，请勿认为已切换成功');
      }
    }
  }

  void rerecord() {
    if (_closed ||
        state.busy ||
        (state.step != CloneStep.candidate &&
            state.step != CloneStep.candidateError)) {
      return;
    }
    if (reuseOnRerecord && !state.showSaveRecording) {
      openCandidate(CloneCreationStart.savedRecording);
      return;
    }
    ++_generation;
    _stopPreview();
    state = const CloneEnrollmentState();
  }

  bool _current(int generation) => !_closed && generation == _generation;
  @override
  void dispose() {
    _closed = true;
    _name = '';
    _identity = '';
    _stopPreview();
    port.close();
    super.dispose();
  }
}
