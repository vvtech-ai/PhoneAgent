import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/tools/conversation_permission.dart';
import '../../domain/voice/manual_voice_transcript.dart';
import '../../domain/voice/voice_gateway_event.dart';
import '../../domain/voice/voice_input_session.dart';
import 'voice_input_state.dart';

/// One conversation input lifecycle; never duplicates Agent submission rules.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    required this.createSession,
    required this.permissions,
    required this.endpoint,
    required this.isCurrent,
    required this.canSubmit,
    required this.submit,
    this.recoveryText,
    this.available = true,
  });
  final VoiceInputSession Function() createSession;
  final ConversationPermissionSource permissions;
  final Uri? endpoint;
  final bool Function() isCurrent, canSubmit;
  final bool Function(String) submit;
  final String Function()? recoveryText;
  final bool available;
  VoiceInputState state = const VoiceInputState();
  VoiceInputSession? _session;
  StreamSubscription<VoiceGatewayEvent>? _subscription;
  Future<void>? _cleanup;
  ManualVoiceTranscript _transcript = ManualVoiceTranscript();
  Timer? _tail, _maximum;
  int _generation = 0;
  bool _closed = false;

  bool _current(int generation) =>
      !_closed && generation == _generation && isCurrent();
  void _set(VoiceInputPhase phase, {String? text, String notice = ''}) {
    if (_closed) return;
    state = VoiceInputState(
      phase: phase,
      text: text ?? _transcript.display,
      notice: notice,
    );
    notifyListeners();
  }

  Future<void> press() async {
    if (_closed || !isCurrent() || !state.canPress || !canSubmit()) return;
    if (!available) {
      _set(
        VoiceInputPhase.failed,
        text: '',
        notice: 'Web 请使用文字输入；语音可在隔离演练或 App 中验证',
      );
      return;
    }
    if (endpoint == null) {
      _set(VoiceInputPhase.failed, text: '', notice: '语音服务地址未配置');
      return;
    }
    final generation = _invalidate();
    _transcript = ManualVoiceTranscript();
    final base = recoveryText?.call().trim() ?? '';
    _transcript.buffered = _transcript.display = base;
    _set(VoiceInputPhase.permission);
    try {
      await _clean();
      if (!_current(generation)) return;
      var grant = await permissions.resolve(
        ConversationPermission.microphone,
        request: false,
      );
      if (!_current(generation)) return;
      if (grant == PermissionGrant.denied) {
        grant = await permissions.resolve(
          ConversationPermission.microphone,
          request: true,
        );
      }
      if (!_current(generation)) return;
      if (grant != PermissionGrant.granted) {
        _set(VoiceInputPhase.failed, notice: '麦克风未授权，请检查系统权限后重新按住说话');
        return;
      }
      if (!canSubmit()) {
        await cancel();
        return;
      }
      final session = _session = createSession();
      _subscription = session.events.listen(
        (event) => _event(event, generation),
        onError: (Object _) => _fail(generation),
        onDone: () {
          if (_current(generation)) _fail(generation);
        },
      );
      _set(VoiceInputPhase.connecting);
      _maximum = Timer(const Duration(seconds: 60), () {
        if (_current(generation)) unawaited(_complete(_transcript.timeoutText));
      });
      await session.start(endpoint!);
    } catch (_) {
      _fail(generation);
    }
  }

  void _event(VoiceGatewayEvent event, int generation) {
    if (!_current(generation)) return;
    if (event is VoiceReady) {
      if (state.phase == VoiceInputPhase.connecting) {
        _set(VoiceInputPhase.recording);
      }
    } else if (event is VoiceRecognitionFallback) {
      _transcript.display = _transcript.buffered;
      _set(
        state.phase == VoiceInputPhase.finalizing
            ? VoiceInputPhase.finalizing
            : VoiceInputPhase.connecting,
        notice: '正在切换备用语音识别',
      );
    } else if (event is VoiceTranscript) {
      if (event.isFinal) {
        if (!_transcript.finalText(event.text)) return;
        if (state.phase == VoiceInputPhase.finalizing) {
          unawaited(_complete(_transcript.buffered));
          return;
        }
      } else {
        _transcript.partial(event.text);
      }
      _set(state.phase);
    } else if (event is VoiceGatewayFailure || event is VoiceTransportClosed) {
      _fail(generation);
    }
  }

  /// v65 keeps capture alive for the final clause, up to two seconds.
  void release() {
    if (_closed) return;
    if (state.phase == VoiceInputPhase.permission) {
      unawaited(cancel());
      return;
    }
    if (state.phase != VoiceInputPhase.connecting &&
        state.phase != VoiceInputPhase.recording) {
      return;
    }
    _maximum?.cancel();
    final generation = _generation;
    _set(VoiceInputPhase.finalizing);
    _tail = Timer(const Duration(seconds: 2), () {
      if (_current(generation)) unawaited(_complete(_transcript.releaseText));
    });
  }

  Future<void> _complete(String text) async {
    final generation = _invalidate(); // Exactly one result may enter submit.
    _set(VoiceInputPhase.stopping, text: text);
    try {
      await _clean();
      if (!_current(generation)) return;
      if (text.isEmpty) {
        _set(VoiceInputPhase.idle, text: '', notice: '未识别到有效语音，请重新按住说话');
      } else if (canSubmit() && submit(text)) {
        if (_current(generation)) _set(VoiceInputPhase.idle, text: '');
      } else {
        _set(
          VoiceInputPhase.failed,
          text: text,
          notice: '当前无法提交语音，请先完成或同步当前对话',
        );
      }
    } catch (_) {
      if (_current(generation)) {
        _set(VoiceInputPhase.failed, text: text, notice: '录音未能正常结束，请重试清理');
      }
    }
  }

  void _fail(int generation) {
    if (!_current(generation)) return;
    unawaited(cancel(notice: '语音识别中断，请重新按住说话或切换文字'));
  }

  int _invalidate() {
    _tail?.cancel();
    _maximum?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    return ++_generation;
  }

  Future<void> _clean() async {
    final session = _session;
    if (session == null) return;
    try {
      await (_cleanup ??= session.cancel());
      if (identical(session, _session)) _session = null;
    } finally {
      _cleanup = null; // A failed stop must remain retryable.
    }
  }

  Future<void> cancel({String notice = ''}) async {
    final generation = _invalidate();
    _set(VoiceInputPhase.stopping, text: '');
    try {
      await _clean();
      if (_current(generation)) {
        _set(VoiceInputPhase.idle, text: '', notice: notice);
      }
    } catch (_) {
      if (_current(generation)) {
        _set(VoiceInputPhase.failed, text: '', notice: '录音未能正常结束，请重试清理');
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _invalidate();
    unawaited(_clean().catchError((Object _) {}));
    super.dispose();
  }
}
