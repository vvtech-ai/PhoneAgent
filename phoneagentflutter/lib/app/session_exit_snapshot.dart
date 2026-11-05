import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// One bounded in-memory frame. No disk/network, session credentials or widgets.
class SessionExitSnapshot {
  SessionExitSnapshot({
    required VoidCallback onReady,
    this.timeout = const Duration(milliseconds: 250),
  }) : _onReady = onReady;
  VoidCallback? _onReady;
  final Duration timeout;
  ui.Image? _image;
  ui.Image? get image => _image;
  bool _disposed = false, _capturing = false;
  int _generation = 0;
  Timer? _timer;

  void begin(Future<ui.Image?> Function() capture) {
    clear();
    if (_disposed || _capturing) return;
    _capturing = true;
    final generation = _generation;
    _timer = Timer(timeout, () {
      if (_generation == generation) _generation++;
    });
    try {
      unawaited(_capture(capture(), generation));
    } catch (_) {
      _capturing = false;
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _capture(Future<ui.Image?> capture, int generation) async {
    ui.Image? result;
    try {
      result = await capture;
    } catch (_) {
      /* Opaque fallback remains. */
    }
    _capturing = false;
    if (_disposed || generation != _generation) {
      result?.dispose();
      return;
    }
    _timer?.cancel();
    _timer = null;
    _image = result;
    if (result != null) _onReady?.call();
  }

  void clear() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _image?.dispose();
    _image = null;
  }

  void dispose() {
    _disposed = true;
    _onReady = null;
    clear();
  }
}
