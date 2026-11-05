import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/presentation/controller/developer_list_controller.dart';
import 'app_call_record_providers.dart';
import 'business_providers.dart';
import 'contact_providers.dart';
import 'conversation_providers.dart';

final developerListControllerProvider =
    StateNotifierProvider.autoDispose<
      DeveloperListController,
      DeveloperListState
    >((ref) {
      ref.watch(loginEpochProvider);
      ref.keepAlive();
      return DeveloperListController(
        records: ref.watch(appCallRecordRepositoryProvider),
        refreshTasks: () async {
          // Hold the offscreen autoDispose task controller until its refresh ends.
          final lease = ref.listen(taskControllerProvider, (_, __) {});
          final tasks = ref.read(taskControllerProvider.notifier);
          try {
            await tasks.refresh();
            return tasks.mounted &&
                ref.read(taskControllerProvider).catalog.failedSources.isEmpty;
          } finally {
            lease.close();
          }
        },
        reloadContacts: () async {
          final contacts = ref.read(contactsControllerProvider.notifier);
          contacts.closeDetail();
          await contacts.loadDevice();
          return contacts.mounted &&
              ref.read(contactsControllerProvider).deviceError.isEmpty;
        },
        clearContacts: () => ref
            .read(contactsControllerProvider.notifier)
            .clearDeviceForDeveloper(),
      );
    });
