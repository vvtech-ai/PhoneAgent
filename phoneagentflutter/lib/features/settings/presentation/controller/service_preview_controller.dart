import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PreviewService { logs, update }

enum ServicePreviewPhase {
  idle,
  checking,
  latest,
  available,
  compressing,
  uploading,
  downloading,
  failed,
  success,
  ready,
  handoff,
}

class ServicePreviewState {
  const ServicePreviewState(this.phase, {this.progress = 0});
  final ServicePreviewPhase phase;
  final double progress;
  bool get busy => [
    ServicePreviewPhase.checking,
    ServicePreviewPhase.compressing,
    ServicePreviewPhase.uploading,
    ServicePreviewPhase.downloading,
  ].contains(phase);
}

/// No network, storage or platform dependencies: deliberate interaction fixture.
class ServicePreviewController extends StateNotifier<ServicePreviewState> {
  ServicePreviewController(
    this.service, {
    this.step = const Duration(milliseconds: 300),
  }) : super(const ServicePreviewState(ServicePreviewPhase.idle));
  final PreviewService service;
  ServicePreviewState get snapshot => state;
  final Duration step;
  bool failNext = false, latest = false;
  Future<bool> _pause() async {
    await Future<void>.delayed(step);
    return mounted;
  }

  Future<void> run() async {
    if (!mounted || state.busy) return;
    if (service == PreviewService.update &&
        [
          ServicePreviewPhase.idle,
          ServicePreviewPhase.latest,
          ServicePreviewPhase.handoff,
        ].contains(state.phase)) {
      state = const ServicePreviewState(ServicePreviewPhase.checking);
      if (!await _pause()) return;
      state = ServicePreviewState(
        latest ? ServicePreviewPhase.latest : ServicePreviewPhase.available,
      );
      return;
    }
    final log = service == PreviewService.logs;
    final fail = failNext;
    failNext = false;
    state = ServicePreviewState(
      log ? ServicePreviewPhase.compressing : ServicePreviewPhase.downloading,
    );
    if (!await _pause()) return;
    state = ServicePreviewState(
      log ? ServicePreviewPhase.uploading : ServicePreviewPhase.downloading,
      progress: .5,
    );
    if (!await _pause()) return;
    state = ServicePreviewState(
      fail
          ? ServicePreviewPhase.failed
          : log
          ? ServicePreviewPhase.success
          : ServicePreviewPhase.ready,
      progress: 1,
    );
  }

  void handoff() {
    if (mounted &&
        service == PreviewService.update &&
        state.phase == ServicePreviewPhase.ready) {
      state = const ServicePreviewState(ServicePreviewPhase.handoff);
    }
  }
}
