import 'dart:async';
import '../../../settings/domain/network_availability.dart';
import '../../../settings/domain/network_availability_events.dart';
import '../translation_call_environment.dart';

/// Local protocol evidence, independent from UI, billing and model credentials.
class DomesticTranslationEnvironment {
  DomesticTranslationEnvironment({
    required this.network,
    required this.isCurrent,
    this.onChanged,
  });
  final NetworkAvailabilitySource network;
  final bool Function() isCurrent;
  final void Function(TranslationCallEnvironment)? onChanged;
  StreamSubscription<NetworkAvailability>? _subscription;
  bool _started = false, _stopped = false;
  int _revision = 0, _networkRevision = 0;
  String _preparing = '';
  var _network = TranslationEnvironmentState.pending;
  var _sip = TranslationEnvironmentState.pending;
  var _model = TranslationEnvironmentState.pending;

  void start() {
    if (_started || _stopped) return;
    _started = true;
    _emit();
    final source = network;
    if (source is NetworkAvailabilityEvents) {
      try {
        _subscription = (source as NetworkAvailabilityEvents).watch().listen(
          (value) {
            _networkRevision++;
            _networkChanged(value);
          },
          onError: (Object _) {
            _networkRevision++;
            _networkChanged(NetworkAvailability.unknown);
          },
        );
      } catch (_) {
        /* An unsupported platform remains unknown. */
      }
    }
    final revision = _networkRevision;
    unawaited(_read(revision));
  }

  Future<void> _read(int revision) async {
    NetworkAvailability value;
    try {
      value = await network.read().timeout(const Duration(seconds: 3));
    } catch (_) {
      value = NetworkAvailability.unknown;
    }
    if (revision == _networkRevision) _networkChanged(value);
  }

  void _networkChanged(NetworkAvailability value) {
    if (_stopped || !isCurrent()) return;
    _network = switch (value) {
      NetworkAvailability.available => TranslationEnvironmentState.available,
      NetworkAvailability.unavailable =>
        TranslationEnvironmentState.unavailable,
      // A completed protocol handshake is positive evidence on platforms
      // without network monitoring; explicit offline always wins above.
      NetworkAvailability.unknown =>
        _network == TranslationEnvironmentState.available
            ? _network
            : TranslationEnvironmentState.pending,
    };
    _emit();
  }

  void preparingModels() {
    _preparing = 'model';
  }

  void preparingSip() {
    _preparing = 'sip';
  }

  void modelReady() {
    _preparing = '';
    _model = TranslationEnvironmentState.available;
    _reachable();
  }

  void sipReady() {
    _preparing = '';
    _sip = TranslationEnvironmentState.available;
    _reachable();
  }

  void _reachable() {
    if (_network == TranslationEnvironmentState.pending) {
      _network = TranslationEnvironmentState.available;
    }
    _emit();
  }

  void modelFailed() {
    _model = TranslationEnvironmentState.unavailable;
    _emit();
  }

  void sipFailed() {
    _sip = TranslationEnvironmentState.unavailable;
    _emit();
  }

  void preparationFailed() {
    if (_preparing == 'model') modelFailed();
    if (_preparing == 'sip') sipFailed();
  }

  void _emit() {
    if (_stopped || !isCurrent()) return;
    try {
      onChanged?.call(
        TranslationCallEnvironment(
          version: ++_revision,
          network: _network,
          sip: _sip,
          model: _model,
        ),
      );
    } catch (_) {
      /* Observers cannot alter call resource ownership. */
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    try {
      await _subscription?.cancel();
    } catch (_) {
      /* No media ownership. */
    }
    _subscription = null;
  }
}
