import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/features/identity/data/preview_identity_cleanup.dart';
import '../../tool/previews/shell_initialization_store.dart';

/// Existing-user fixtures bypass onboarding by data, not a production gate flag.
List<Override> initializedIdentityOverrides() {
  final identity = PreviewIdentityCleanup();
  return [
    identityRepositoryProvider.overrideWithValue(identity),
    identityInitializationStoreProvider.overrideWithValue(
      ShellInitializationStore(identity),
    ),
  ];
}
