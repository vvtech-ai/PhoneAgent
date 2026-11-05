import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/app/developer_list_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/dialer/data/preview_app_call_record_store.dart';
import 'package:phone_agent/features/settings/presentation/controller/developer_list_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/app_call_records_preview_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 844),
  ]) {
    testWidgets('shared list append select clear fill failure retry at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: AppCallRecordsPreviewPage()),
      );
      await tester.pumpAndSettle();
      Future<void> press(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('当前联系人：3'), findsOneWidget);
      await press('追加合成翻译记录');
      await press('合成翻译通话');
      expect(find.textContaining('选中号码：+12025550101'), findsOneWidget);
      await press('清空列表');
      expect(find.text('合成翻译通话'), findsNothing);
      expect(find.text('合成系统记录（清空不影响）'), findsOneWidget);
      expect(find.textContaining('当前联系人：0'), findsOneWidget);
      await press('重新拉取');
      expect(find.textContaining('当前联系人：3 · 任务刷新：1'), findsOneWidget);
      await press('追加合成翻译记录');
      await press('模拟本机保存失败');
      await press('清空列表');
      expect(find.textContaining('清空失败'), findsOneWidget);
      expect(find.text('合成翻译通话'), findsOneWidget);
      await press('模拟本机保存失败');
      await press('清空列表');
      expect(find.text('合成翻译通话'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'formal providers share offscreen contacts and recreate on account epoch',
    () async {
      final epoch = StateProvider<int>((_) => 1);
      final store = PreviewAppCallRecordStore();
      final device = PreviewContacts();
      final tasks = _Tasks();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          appCallRecordRepositoryProvider.overrideWithValue(store.repository),
          deviceContactSourceProvider.overrideWithValue(device),
          contactDirectoryRepositoryProvider.overrideWithValue(
            device.directory,
          ),
          taskRepositoryProvider.overrideWithValue(tasks),
          taskErrorStatusSyncProvider.overrideWith((ref) {
            final sync = PreviewTaskErrorStatusPorts().createSync();
            ref.onDispose(sync.close);
            return sync;
          }),
          accountApiProvider.overrideWith(
            (_) => throw StateError('No network allowed'),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(store.repository.close);
      final controller = container.read(
        developerListControllerProvider.notifier,
      );
      await controller.apply(DeveloperListMode.empty);
      await container.pump();
      expect(container.read(contactsControllerProvider).contacts, isEmpty);
      expect(tasks.reads, 0);
      await controller.apply(DeveloperListMode.filled);
      expect(container.read(contactsControllerProvider).contacts.length, 3);
      expect(tasks.reads, greaterThanOrEqualTo(TaskSource.values.length));
      expect(controller.state.failed, isFalse);
      container
          .read(contactsControllerProvider.notifier)
          .openDetail(
            container.read(contactsControllerProvider).contacts.first,
          );
      await controller.apply(DeveloperListMode.filled);
      expect(container.read(contactsControllerProvider).selected, isNull);
      await controller.apply(DeveloperListMode.empty);
      await container.pump();
      expect(
        container.read(developerListControllerProvider.notifier),
        same(controller),
      );
      container.read(epoch.notifier).state = 2;
      final next = container.read(developerListControllerProvider.notifier);
      expect(next, isNot(same(controller)));
      expect(controller.mounted, isFalse);
      await container.read(contactsControllerProvider.notifier).loadDevice();
      expect(container.read(contactsControllerProvider).contacts.length, 3);
    },
  );
}

class _Tasks implements TaskRepository {
  int reads = 0;
  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    reads++;
    return const [];
  }
}
