import 'features/trusted_caller/data/device_trusted_identity_display_port.dart';
import 'features/trusted_caller/presentation/pages/trusted_identity_overlay_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/phone_agent_app.dart';
import 'app/android_startup_host.dart';
import 'app/runtime_diagnostics_host.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Stable semantic controls for browser automation; no coordinate-only layer.
  if (kIsWeb && kDebugMode) WidgetsBinding.instance.ensureSemantics();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final config = AppConfig.parse(
    environment: const String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    sdkApiBaseUrl: const String.fromEnvironment('SDK_API_BASE_URL'),
    runtimeApiBaseUrl: const String.fromEnvironment('RUNTIME_API_BASE_URL'),
    release: kReleaseMode,
  );
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const AndroidStartupHost(
        child: RuntimeDiagnosticsHost(child: PhoneAgentApp()),
      ),
    ),
  );
}

/// Separate iOS display engine; main application services remain in main().
@pragma('vm:entry-point')
void trustedIdentityOverlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TrustedIdentityOverlayApp(port: DeviceTrustedIdentityDisplayPort()));
}
