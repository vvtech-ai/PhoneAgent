import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/developer_network_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_actions.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/settings/domain/developer_network_mode.dart';
import 'package:phone_agent/features/shell/presentation/pages/shell_route.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import '../../support/shell_fakes.dart';
import '../../../tool/previews/shell_task_parity_ports.dart';

Widget _shellApp() {
  final observer = PageRouteVisibilityObserver();
  return PageRouteVisibilityScope(
    observer: observer,
    child: MaterialApp(
      navigatorObservers: [observer],
      home: const ShellRoute(),
    ),
  );
}

void main() {
  Future<void> press(WidgetTester tester, String label) async {
    final item = find.text(label);
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  for (final simulated in [true, false]) {
    testWidgets(
      'formal home and task restoration stop before conversation provider (simulated=$simulated)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...shellTaskParityOverrides(),
              currentAccountIdProvider.overrideWithValue(
                'synthetic-network-entry',
              ),
              taskErrorStatusSyncProvider.overrideWith((ref) {
                final sync = PreviewTaskErrorStatusPorts().createSync();
                ref.onDispose(sync.close);
                return sync;
              }),
              developerNetworkModeProvider.overrideWith(
                (_) => simulated
                    ? DeveloperNetworkMode.offline
                    : DeveloperNetworkMode.normal,
              ),
              networkAvailabilitySourceProvider.overrideWithValue(
                const _OfflineSource(),
              ),
              accountApiProvider.overrideWith(
                (_) => throw StateError('No real API allowed'),
              ),
              agentGatewayProvider.overrideWith(
                (_) => throw StateError('Must not enter conversation'),
              ),
              homeControllerProvider.overrideWith(
                (_) => HomeController(FakeHomeRepository()),
              ),
              callModelControllerProvider.overrideWith(
                (_) => CallModelController(FakeCallModelRepository()),
              ),
              pointsWalletControllerProvider.overrideWith(
                (_) => PointsWalletController(_UnusedWallet()),
              ),
              taskControllerProvider.overrideWith(
                (_) => TaskController(_Tasks())..refresh(),
              ),
            ],
            child: _shellApp(),
          ),
        );
        await tester.pumpAndSettle();
        await press(tester, '订餐厅');
        expect(find.text('无网络连接'), findsOneWidget);
        await press(tester, '关闭');
        await press(tester, '任务');
        await press(tester, 'AI 通话 · 合成已完成任务');
        expect(find.text('无网络连接'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('AI 通话 · 合成已完成任务'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'formal contact skill selection cannot start session while offline',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskErrorStatusSyncProvider.overrideWith((ref) {
              final sync = PreviewTaskErrorStatusPorts().createSync();
              ref.onDispose(sync.close);
              return sync;
            }),
            developerNetworkModeProvider.overrideWith(
              (_) => DeveloperNetworkMode.offline,
            ),
            accountApiProvider.overrideWith(
              (_) => throw StateError('No real API allowed'),
            ),
            agentGatewayProvider.overrideWith(
              (_) => throw StateError('Must not enter conversation'),
            ),
            homeControllerProvider.overrideWith(
              (_) => HomeController(FakeHomeRepository()),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showContactSkills(
                    context,
                    const ContactRecord(
                      name: '合成联系人',
                      phone: '+12025550123',
                      systemDialPhone: '+12025550123',
                    ),
                    preview: false,
                  ),
                  child: const Text('联系人需求'),
                ),
              ),
            ),
          ),
        ),
      );
      await press(tester, '联系人需求');
      await press(tester, '订餐厅');
      expect(find.text('无网络连接'), findsOneWidget);
      await press(tester, '关闭');
      expect(find.text('联系人需求'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing shell tab while sampling cannot open stale conversation',
    (tester) async {
      final source = _PendingSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...shellTaskParityOverrides(),
            currentAccountIdProvider.overrideWithValue(
              'synthetic-network-entry',
            ),
            taskErrorStatusSyncProvider.overrideWith((ref) {
              final sync = PreviewTaskErrorStatusPorts().createSync();
              ref.onDispose(sync.close);
              return sync;
            }),
            networkAvailabilitySourceProvider.overrideWithValue(source),
            accountApiProvider.overrideWith(
              (_) => throw StateError('No real API allowed'),
            ),
            agentGatewayProvider.overrideWith(
              (_) => throw StateError('Stale conversation opened'),
            ),
            homeControllerProvider.overrideWith(
              (_) => HomeController(FakeHomeRepository()),
            ),
            callModelControllerProvider.overrideWith(
              (_) => CallModelController(FakeCallModelRepository()),
            ),
            pointsWalletControllerProvider.overrideWith(
              (_) => PointsWalletController(_UnusedWallet()),
            ),
            taskControllerProvider.overrideWith(
              (_) => TaskController(_Tasks())..refresh(),
            ),
          ],
          child: _shellApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('订餐厅'));
      await tester.pump();
      await press(tester, '任务');
      source.pending.complete(NetworkAvailability.available);
      await tester.pumpAndSettle();
      expect(find.text('AI 通话 · 合成已完成任务'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PendingSource implements NetworkAvailabilitySource {
  final pending = Completer<NetworkAvailability>();
  @override
  Future<NetworkAvailability> read() => pending.future;
}

class _UnusedWallet implements PointsWalletRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No wallet call expected');
}

class _OfflineSource implements NetworkAvailabilitySource {
  const _OfflineSource();
  @override
  Future<NetworkAvailability> read() async => NetworkAvailability.unavailable;
}

class _Tasks implements TaskRepository {
  @override
  Future<List<TaskRecord>> load(TaskSource source) async =>
      source == TaskSource.conversations
      ? [
          const TaskRecord(
            id: 'synthetic',
            kind: TaskRecordKind.conversation,
            title: '合成已完成任务',
            status: TaskStatus.completed,
            rawStatus: 'COMPLETED',
            sessionId: 'synthetic-session',
          ),
        ]
      : [];
}
