import 'dart:async';
import 'package:flutter/widgets.dart';

/// Settings launch acknowledgement is distinct from the user's app return.
Future<void> waitForPermissionSettingsReturn(
  Future<void> Function() open, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final observer = _SettingsReturn();
  WidgetsBinding.instance.addObserver(observer);
  try {
    await open().timeout(timeout);
    await observer.returned.future.timeout(timeout);
  } finally {
    WidgetsBinding.instance.removeObserver(observer);
  }
}

class _SettingsReturn extends WidgetsBindingObserver {
  final returned = Completer<void>();
  bool _left = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _left = true;
    if (_left && state == AppLifecycleState.resumed && !returned.isCompleted) {
      returned.complete();
    }
  }
}
