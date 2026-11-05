import '../features/trusted_caller/presentation/controller/trusted_identity_surface_controller.dart';
import 'dart:async';
import '../features/trusted_caller/data/device_trusted_identity_surface_port.dart';
import '../features/trusted_caller/domain/trusted_identity_surface_port.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/diagnostics/diagnostic_event.dart';
import '../features/trusted_caller/data/trusted_incoming_diagnostics.dart';
import '../features/trusted_caller/domain/trusted_caller.dart';
import '../features/trusted_caller/domain/trusted_incoming_identity.dart';
import '../features/trusted_caller/data/device_trusted_incoming_identity_port.dart';
import '../features/trusted_caller/presentation/controller/trusted_incoming_identity_controller.dart';
import 'app_providers.dart';
import 'trusted_caller_diagnostics_providers.dart';
import 'trusted_caller_providers.dart';

final trustedIncomingIdentityPortProvider =
    Provider<TrustedIncomingIdentityPort>(
      (ref) => DeviceTrustedIncomingIdentityPort(
        diagnostics: ref.read(trustedCallerDiagnosticsProvider),
      ),
    );
final trustedIncomingIdentityControllerProvider =
    StateNotifierProvider.autoDispose<
      TrustedIncomingIdentityController,
      TrustedIncomingIdentity?
    >((ref) {
      final owner = ref.watch(trustedCallerOwnerProvider);
      final config = ref.watch(appConfigProvider);
      var active = true;
      ref.onDispose(() => active = false);
      final enabled =
          owner != null &&
          config.isConfigured &&
          config.environment != AppEnvironment.local;
      return TrustedIncomingIdentityController(
        owner: owner ?? const TrustedCallerOwner('', '', -1),
        events: enabled
            ? ref
                  .watch(trustedIncomingIdentityPortProvider)
                  .watch(
                    owner,
                    config.environment == AppEnvironment.prod ? 'pro' : 'test',
                  )
            : const Stream.empty(),
        isCurrent: (captured) =>
            active &&
            ref.read(trustedCallerOwnerProvider)?.matches(captured) == true,
      );
    });

final trustedIncomingPresentationDiagnosticsProvider =
    Provider<void Function(String)>((ref) {
      final config = ref.watch(appConfigProvider);
      final owner = ref.watch(trustedCallerOwnerProvider);
      final sink = ref.read(trustedCallerDiagnosticsProvider);
      var active = true;
      ref.onDispose(() => active = false);
      return (code) {
        if (!active ||
            owner == null ||
            ref.read(trustedCallerOwnerProvider)?.matches(owner) != true) {
          return;
        }
        TrustedIncomingDiagnostics(
          sink(),
          config.environment == AppEnvironment.prod ? 'pro' : 'test',
        ).record(
          DiagnosticTrustedCallerStage.incomingPresentation,
          code,
          code == 'IOS_PRESENTED'
              ? DiagnosticResult.succeeded
              : DiagnosticResult.received,
        );
      };
    });

final trustedIdentitySurfacePortProvider =
    Provider.autoDispose<TrustedIdentitySurfacePort>((ref) {
      final config = ref.watch(appConfigProvider);
      final port = DeviceTrustedIdentitySurfacePort(
        environment: config.environment == AppEnvironment.prod ? 'pro' : 'test',
      );
      ref.onDispose(() => unawaited(port.dispose()));
      return port;
    });

final trustedIdentitySurfaceControllerProvider =
    StateNotifierProvider.autoDispose<
      TrustedIdentitySurfaceController,
      TrustedIncomingIdentity?
    >((ref) {
      final controller = TrustedIdentitySurfaceController(
        port: ref.watch(trustedIdentitySurfacePortProvider),
        onDismiss: (id) => ref
            .read(trustedIncomingIdentityControllerProvider.notifier)
            .dismiss(id),
        onDiagnostic: (code) =>
            ref.read(trustedIncomingPresentationDiagnosticsProvider)(code),
      );
      // A real subscription is required: widget rebuilds stop under native full-screen UI.
      ref.listen(
        trustedIncomingIdentityControllerProvider,
        (_, value) => controller.update(value),
        fireImmediately: true,
      );
      return controller;
    });
