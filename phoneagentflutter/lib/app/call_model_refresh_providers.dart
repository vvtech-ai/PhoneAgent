import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'business_providers.dart';

/// Shared entry point; the controller owns request ordering and account scope.
final callModelRefreshProvider = Provider.autoDispose<Future<void> Function()>((
  ref,
) {
  ref.watch(loginEpochProvider);
  return () => ref.read(callModelControllerProvider.notifier).load();
});
