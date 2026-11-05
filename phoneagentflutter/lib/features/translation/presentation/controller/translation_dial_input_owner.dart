import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/dialer_providers.dart';
import '../../../../app/settings_providers.dart';
import '../../../../app/app_call_record_providers.dart';
import '../../../dialer/data/system_dialer_channel.dart';
import '../../../dialer/domain/system_dialer.dart';
import '../../../dialer/presentation/controller/dialer_controller.dart';
import 'translation_setup_controller.dart';

/// Formal drafts belong to the login; isolated inputs belong to their route.
class TranslationDialInputOwner {
  TranslationDialInputOwner(
    WidgetRef ref, {
    required bool preview,
    required this.translationEntry,
    SystemDialer? port,
  }) : owned = preview || port != null {
    controller = owned
        ? DialerController(
            port ?? PreviewSystemDialer(),
            preview: preview,
            onOpened: preview
                ? null
                : ref.read(appDialHistoryRecorderProvider)?.systemHandoff,
            onUnlockDeveloper: preview
                ? null
                : () => ref.read(developerModeProvider.notifier).state = true,
          )
        : ref.read(dialerControllerProvider.notifier);
  }
  final bool owned, translationEntry;
  late final DialerController controller;
  bool _active = true, _queued = false, _applied = false;

  bool current(WidgetRef ref) =>
      _active &&
      controller.mounted &&
      (owned ||
          identical(controller, ref.read(dialerControllerProvider.notifier)));

  void applyEntryMode(
    TranslationSetupController setup, {
    required bool Function() current,
  }) {
    if (!translationEntry || _applied || _queued || !setup.status.ready) return;
    _queued = true;
    scheduleMicrotask(() {
      _queued = false;
      if (!_active || !setup.mounted || !current()) return;
      _applied = true;
      setup.enable(true);
    });
  }

  void release() {
    _active = false;
    if (owned) controller.dispose();
  }
}
