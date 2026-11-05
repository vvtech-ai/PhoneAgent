import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/contacts/data/api_contact_directory_repository.dart';
import '../features/contacts/domain/contact_records.dart';
import '../features/contacts/presentation/controller/contacts_controller.dart';
import '../features/contacts/presentation/controller/contact_system_dial_controller.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';
import 'dialer_providers.dart';
import 'dial_permission_providers.dart';
import 'about_providers.dart';
import '../features/contacts/presentation/controller/contact_skills_controller.dart';

export 'conversation_providers.dart' show deviceContactSourceProvider;

// Normal Web remains unsupported. The isolated workbench may exercise the
// same route as mobile only when it also supplies synthetic external ports.
final contactsSharedFlowEnabledProvider = Provider<bool>((ref) => !kIsWeb);

final contactSystemDialControllerProvider =
    StateNotifierProvider<ContactSystemDialController, bool>((ref) {
      ref.watch(loginEpochProvider);
      return ContactSystemDialController(ref.watch(systemDialerProvider));
    });

final contactDirectoryRepositoryProvider =
    Provider.autoDispose<ContactDirectoryRepository>(
      (ref) => ApiContactDirectoryRepository(
        ref.watch(accountApiProvider),
        ref.watch(currentAccountIdProvider),
      ),
    );
final contactsControllerProvider =
    StateNotifierProvider.autoDispose<ContactsController, ContactsState>((ref) {
      ref.watch(loginEpochProvider);
      // The developer Empty action is process-local state, including offscreen.
      // Ownership changes still dispose and recreate this controller.
      ref.keepAlive();
      final controller = ContactsController(
        ref.watch(deviceContactSourceProvider),
        ref.watch(contactDirectoryRepositoryProvider),
      );
      controller.loadDevice();
      controller.loadDirectory();
      return controller;
    });

/// Reuse the existing application-settings adapter without requesting location.
final contactSettingsLauncherProvider = Provider<Future<void> Function()>((
  ref,
) {
  return ref.watch(dialPermissionPortProvider).openSettings;
});

final contactSkillsControllerProvider =
    StateNotifierProvider.autoDispose<
      ContactSkillsController,
      ContactSkillsState
    >((ref) {
      ref.watch(loginEpochProvider);
      final controller = ContactSkillsController(
        ref.watch(homeRepositoryProvider),
        ref.watch(aboutMetadataSourceProvider),
      );
      controller.load();
      return controller;
    });
