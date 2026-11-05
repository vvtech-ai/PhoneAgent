import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/calls/data/call_monitor_stream.dart';
import '../features/calls/data/device_call_monitor_output.dart';
import '../features/calls/data/focused_call_monitor_media.dart';
import '../features/calls/presentation/controller/call_monitor_controller.dart';
import 'app_providers.dart';
import 'audio_focus_providers.dart';
import 'call_session_providers.dart';
import 'task_voice_transport_providers.dart';
import 'media_diagnostics_providers.dart';
import '../core/diagnostics/media_diagnostics.dart';

final callMonitorFactoryProvider =
    Provider.autoDispose<CallMonitorController Function()>((ref) {
      final repository = ref.watch(callSessionRepositoryProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final base = ref.watch(appConfigProvider).runtimeApiBaseUri;
      final transport = ref.watch(taskVoiceTransportProvider);
      final focus = ref.watch(audioPlaybackFocusProvider);
      var active = true;
      ref.onDispose(() => active = false);
      bool current() =>
          active && owner != null && owner.sameLogin(session.credentials);
      return () {
        final diagnostics = ref
            .read(mediaDiagnosticScopeFactoryProvider)()
            .forComponent(DiagnosticMediaComponent.callMonitor);
        late final CallMonitorController controller;
        controller = CallMonitorController(
          loadTicket: repository.monitorTicket,
          isCurrent: current,
          diagnostics: diagnostics,
          supported: !kIsWeb && base != null,
          createMedia: () => FocusedCallMonitorMedia(
            focus: focus,
            isCurrent: current,
            onInterrupted: () => unawaited(controller.stop()),
            delegate: CallMonitorStream(
              apiBase: base!,
              connect: transport.open,
              output: DeviceCallMonitorOutput(),
              diagnostics: diagnostics,
            ),
          ),
        );
        return controller;
      };
    });
