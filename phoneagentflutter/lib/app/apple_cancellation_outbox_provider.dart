import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/commerce/data/secure_apple_cancellation_store.dart';
import '../features/commerce/domain/apple_cancellation_outbox.dart';
import 'app_providers.dart';
import 'business_providers.dart';

// One outbox/startup marker per login, independent of page/controller recreation.
final appleCancellationOutboxProvider = Provider<AppleCancellationOutbox?>((
  ref,
) {
  ref.watch(loginEpochProvider);
  final session = ref.read(sessionControllerProvider.notifier);
  final owner = session.credentials;
  if (owner == null) return null;
  final config = ref.watch(appConfigProvider);
  final scope =
      '${config.environment?.name}|${config.sdkApiBaseUri ?? config.apiBaseUri}|${owner.accountId}';
  var active = true;
  ref.onDispose(() => active = false);
  bool current() => active && owner.sameLogin(session.credentials);
  return AppleCancellationOutbox(
    SecureAppleCancellationStore(scope: scope, isCurrent: current),
    scope: scope,
    isCurrent: current,
  );
});
