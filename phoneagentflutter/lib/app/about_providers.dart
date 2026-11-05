import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/app_update/domain/app_update.dart';
import '../features/app_update/data/installed_app_channel.dart';

final aboutMetadataSourceProvider = Provider<InstalledAppSource>(
  (_) => const InstalledAppChannel(),
);

/// Read installed metadata without update checks, permissions or account IO.
final aboutVersionProvider = FutureProvider.autoDispose<InstalledApp>(
  (ref) => ref.watch(aboutMetadataSourceProvider).read(),
);
