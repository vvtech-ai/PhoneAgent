import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/app_update/data/installed_app_channel.dart';
import '../features/home/data/secure_home_card_preferences.dart';
import '../features/home/domain/home_card_preferences.dart';
import '../features/home/presentation/controller/home_card_preference_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';

final homeInstalledVersionProvider = FutureProvider<String>(
  (_) async => (await const InstalledAppChannel().read()).versionName,
);
final homeCardPreferenceRepositoryProvider =
    Provider.autoDispose<HomeCardPreferenceRepository>((ref) {
      ref.watch(loginEpochProvider);
      final config = ref.watch(appConfigProvider);
      return SecureHomeCardPreferences([
        config.environment?.name ?? '',
        '${config.apiBaseUri}',
        ref.watch(currentAccountIdProvider),
      ]);
    });
final homeCardPreferenceProvider =
    ChangeNotifierProvider.autoDispose<HomeCardPreferenceController>((ref) {
      final controller = HomeCardPreferenceController(
        ref.watch(homeCardPreferenceRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
