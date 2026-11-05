import 'dart:async';
import '../../domain/voice/voice_gateway_event.dart';
import '../../domain/voice/voice_input_session.dart';

/// One gesture, at most two transports. Never replays PCM or owns submission.
class FallbackVoiceInputSession implements VoiceInputSession {
  FallbackVoiceInputSession({
    required VoiceInputSession primary,
    required this.createFallback,
    required this.fallbackEndpoint,
    required this.isCurrent,
    this.readLanguage,
  }) : _active = primary;
  final VoiceInputSession Function() createFallback;
  final Uri fallbackEndpoint;
  final bool Function() isCurrent;
  final Future<String> Function()? readLanguage;
  String? _language;
  VoiceInputSession _active;
  final _events = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  StreamSubscription<VoiceGatewayEvent>? _subscription;
  Future<void>? _cleanup;
  int _generation = 0;
  bool _used = false, _cancelled = false, _released = false;
  bool _fallbackUsed = false, _switching = false, _terminal = false;
  static const _eligibleErrors = {
    'provider_error',
    'connect_failed',
    'transport_error',
    'send_failed',
    'ready_timeout',
    'invalid_frame',
  };
  @override
  Stream<VoiceGatewayEvent> get events => _events.stream;

  bool _current(int generation) =>
      !_cancelled && !_terminal && generation == _generation && isCurrent();

  @override
  Future<void> start(Uri endpoint) async {
    if (_used || _cancelled) throw StateError('Fallback session already used');
    _used = true;
    if (!_current(_generation)) return;
    if (readLanguage != null) {
      final language = await readLanguage!().timeout(
        const Duration(seconds: 3),
      );
      if (!_current(_generation) || _released) return;
      if (!const {'zh-CN', 'en-US', 'ja-JP'}.contains(language)) {
        throw const FormatException('Invalid recognition language');
      }
      _language = language;
    }
    await _startActive(_withLanguage(endpoint));
  }

  Uri _withLanguage(Uri endpoint) => _language == null
      ? endpoint
      : endpoint.replace(
          queryParameters: {
            ...endpoint.queryParameters,
            'languageCode': _language!,
          },
        );

  Future<void> _startActive(Uri endpoint) async {
    final generation = ++_generation;
    if (!_current(generation)) return;
    _subscription = _active.events.listen(
      (event) => _onEvent(event, generation),
      onError: (Object _) =>
          _onEvent(const VoiceGatewayFailure('transport_error'), generation),
      onDone: () =>
          _onEvent(const VoiceTransportClosed('provider_closed'), generation),
    );
    try {
      await _active.start(endpoint);
    } catch (_) {
      _onEvent(const VoiceGatewayFailure('session_start_failed'), generation);
    }
  }

  void _onEvent(VoiceGatewayEvent event, int generation) {
    if (!_current(generation)) return;
    if (event is VoiceGatewayFailure &&
        !_released &&
        !_fallbackUsed &&
        _eligibleErrors.contains(event.message)) {
      _fallbackUsed = true;
      _switching = true;
      ++_generation; // Invalidate before any asynchronous hardware shutdown.
      _events.add(const VoiceRecognitionFallback());
      unawaited(_switch());
      return;
    }
    if (event is VoiceGatewayFailure || event is VoiceTransportClosed) {
      _terminal = true;
    }
    _events.add(event);
  }

  Future<void> _switch() async {
    try {
      // Event subscriptions own no hardware. Generation already rejects late
      // callbacks; actual shutdown is awaited through the session below.
      unawaited(_subscription?.cancel());
      _subscription = null;
      await _cleanActive();
      if (_cancelled || _released || !isCurrent()) return;
      _active = createFallback();
      _switching = false;
      await _startActive(_withLanguage(fallbackEndpoint));
    } catch (_) {
      if (!_cancelled && !_terminal && isCurrent()) {
        _terminal = true;
        _events.add(
          const VoiceGatewayFailure('fallback_start_or_cleanup_failed'),
        );
      }
    } finally {
      _switching = false;
    }
  }

  Future<void> _cleanActive() => _cleanup ??= Future<void>.sync(
    _active.cancel,
  ).whenComplete(() => _cleanup = null);

  /// Explicit hardware stop. The UI's release gesture retains its usual tail.
  @override
  Future<void> release() async {
    _released = true;
    if (_switching) {
      await _cleanActive();
    } else if (!_cancelled) {
      await _active.release();
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _cleanActive(); // Failed shutdown remains retryable; don't lose owner.
    await _events.close();
  }
}
