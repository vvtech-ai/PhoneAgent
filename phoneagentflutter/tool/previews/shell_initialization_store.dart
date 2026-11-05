import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/identity/data/identity_initialization_store.dart';
import 'package:phone_agent/features/identity/data/preview_identity_cleanup.dart';

/// Uses the same synthetic skip state as identity deletion; no device storage.
class ShellInitializationStore extends IdentityInitializationStore {
  ShellInitializationStore(this.identity)
    : super(
        AppConfig.parse(
          environment: 'local',
          apiBaseUrl: 'https://synthetic.invalid/',
        ),
      );
  final PreviewIdentityCleanup identity;
  @override
  Future<bool> isSkipped() async => identity.skipWrites > 0;
  @override
  Future<void> markSkipped() async {
    identity.skipWrites++;
  }
}
