import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../settings/domain/network_availability.dart';
import '../../../settings/domain/network_availability_events.dart';
import '../widgets/conversation_precheck_presentation.dart';
export '../widgets/conversation_precheck_presentation.dart'
    show ConversationPrecheckStage;

/// v66 entry presentation only. Model facts and call admission keep their owners.
class ConversationPrecheckController extends ChangeNotifier {
  ConversationPrecheckController(
    NetworkAvailabilitySource source,
    NetworkAvailabilityEvents events,
  ) {
    _subscription = events.watch().listen(
      _networkChanged,
      onError: (_) {
        _networkChanged(NetworkAvailability.unknown);
      },
    );
    final revision = _networkRevision;
    unawaited(_readNetwork(source, revision));
    _startTimer();
  }
  ConversationPrecheckStage stage = ConversationPrecheckStage.network;
  NetworkAvailability _network = NetworkAvailability.unknown;
  StreamSubscription<NetworkAvailability>? _subscription;
  Timer? _timer;
  bool _closed = false, _elapsed = false, _networkPending = true;
  bool _modelReady = false, _modelBlocked = false, _simulatedOffline = false;
  bool _weakNetwork = false;
  String _modelName = '实时语音模型', _modelError = '';
  int _networkRevision = 0;

  bool get blocked =>
      _network == NetworkAvailability.unavailable ||
      _simulatedOffline ||
      _modelBlocked;
  ConversationPrecheckPresentation get presentation =>
      ConversationPrecheckPresentation.from(
        stage: stage,
        networkUnavailable:
            _network == NetworkAvailability.unavailable || _simulatedOffline,
        weakNetwork: _weakNetwork,
        modelReady: _modelReady,
        modelBlocked: _modelBlocked,
        modelName: _modelName,
        modelError: _modelError,
      );
  String get label => presentation.label;

  void model({
    required bool ready,
    required bool blocked,
    String name = '实时语音模型',
    String error = '',
  }) {
    if (_closed ||
        (_modelReady == ready &&
            _modelBlocked == blocked &&
            _modelName == name &&
            _modelError == error)) {
      return;
    }
    _modelReady = ready;
    _modelBlocked = blocked;
    _modelName = name;
    _modelError = error.trim();
    _advance();
    notifyListeners();
  }

  void simulateOffline(bool value) {
    if (_closed || _simulatedOffline == value) return;
    _simulatedOffline = value;
    _advance();
    notifyListeners();
  }

  void simulateWeak(bool value) {
    if (_closed || _weakNetwork == value) return;
    _weakNetwork = value;
    notifyListeners();
  }

  Future<void> _readNetwork(
    NetworkAvailabilitySource source,
    int revision,
  ) async {
    NetworkAvailability value;
    try {
      value = await source.read();
    } catch (_) {
      value = NetworkAvailability.unknown;
    }
    if (!_closed && revision == _networkRevision) _networkChanged(value);
  }

  void _networkChanged(NetworkAvailability value) {
    if (_closed) return;
    _networkRevision++;
    _networkPending = false;
    _network = value;
    _advance();
    notifyListeners();
  }

  void _advance() {
    if (!_elapsed || blocked || _networkPending) return;
    if (stage != ConversationPrecheckStage.network && !_modelReady) return;
    if (stage == ConversationPrecheckStage.complete) return;
    stage = ConversationPrecheckStage.values[stage.index + 1];
    _elapsed = false;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final duration = switch (stage) {
      ConversationPrecheckStage.network => 300,
      ConversationPrecheckStage.model ||
      ConversationPrecheckStage.outbound => 350,
      ConversationPrecheckStage.passed => 500,
      ConversationPrecheckStage.complete => null,
    };
    if (duration == null) return;
    _timer = Timer(Duration(milliseconds: duration), () {
      if (_closed) return;
      _elapsed = true;
      _advance();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
