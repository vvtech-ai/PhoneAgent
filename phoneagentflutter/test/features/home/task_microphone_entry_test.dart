import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../support/conversation_fakes.dart';
import '../../support/initialized_identity.dart';
import '../../support/pump_ui_transitions.dart';
import '../../support/shell_fakes.dart';

class EntryPermissions
    implements
        ConversationPermissionSource,
        ConversationPermissionSettingsSource {
  PermissionGrant current = PermissionGrant.denied;
  PermissionGrant result = PermissionGrant.denied;
  final requests = <bool>[];
  Completer<PermissionGrant>? pending;
  Completer<void>? settingsReturn;
  Completer<PermissionGrant>? settingsRead;
  int settings = 0;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    if (permission != ConversationPermission.microphone) {
      return PermissionGrant.granted;
    }
    requests.add(request);
    if (!request) {
      return settings > 0 ? settingsRead?.future ?? current : current;
    }
    return pending?.future ?? result;
  }

  @override
  Future<void> openSettings() async {
    settings++;
    await settingsReturn?.future;
    current = PermissionGrant.granted;
  }
}

Future<void> app(WidgetTester tester, EntryPermissions permissions) async {
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...initializedIdentityOverrides(),
        conversationPermissionSourceProvider.overrideWithValue(permissions),
        voiceInputAvailableProvider.overrideWithValue(false),
        networkAvailabilitySourceProvider.overrideWithValue(
          const UnknownNetworkAvailability(),
        ),
        sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
        callModelRepositoryProvider.overrideWithValue(
          FakeCallModelRepository(),
        ),
        taskRepositoryProvider.overrideWithValue(OfflineTasks()),
        taskErrorStatusSyncProvider.overrideWith((ref) {
          final sync = PreviewTaskErrorStatusPorts().createSync();
          ref.onDispose(sync.close);
          return sync;
        }),
        historyRepositoryProvider.overrideWithValue(OfflineHistory()),
        agentGatewayProvider.overrideWithValue(OfflineAgent()),
      ],
      child: const PhoneAgentApp(),
    ),
  );
  await tester.pumpUntilUiSettled();
}

Future<void> tapTask(WidgetTester tester) async {
  final target = find.byKey(const ValueKey('skill-restaurant_booking'));
  await Scrollable.ensureVisible(tester.element(target));
  await tester.pumpUntilUiSettled();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets('task list continuation also refuses entry without microphone', (
    tester,
  ) async {
    final permissions = EntryPermissions();
    await app(tester, permissions);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const ValueKey('conversation:closed')));
    await tester.pumpUntilUiSettled();
    expect(find.byType(ConversationRoute), findsNothing);
    expect(permissions.requests, [false, true]);
    expect(find.byKey(const ValueKey('conversation:closed')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'denial stays home and another explicit card tap can request again',
    (tester) async {
      final permissions = EntryPermissions();
      await app(tester, permissions);
      await tapTask(tester);
      await tester.pumpUntilUiSettled();
      expect(find.byType(ConversationRoute), findsNothing);
      expect(permissions.requests, [false, true]);
      await tapTask(tester);
      await tester.pumpUntilUiSettled();
      expect(permissions.requests, [false, true, false, true]);
      expect(find.byType(ConversationRoute), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('pending grant waits and double tap enters exactly once', (
    tester,
  ) async {
    final permissions = EntryPermissions()
      ..pending = Completer<PermissionGrant>();
    await app(tester, permissions);
    await tapTask(tester);
    await tapTask(tester);
    expect(find.byType(ConversationRoute), findsNothing);
    expect(permissions.requests, [false, true]);
    permissions.pending!.complete(PermissionGrant.granted);
    await tester.pumpUntilUiSettled();
    expect(find.byType(ConversationRoute), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('switching home tab invalidates a late microphone grant', (
    tester,
  ) async {
    final permissions = EntryPermissions()
      ..pending = Completer<PermissionGrant>();
    await app(tester, permissions);
    await tapTask(tester);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pump();
    permissions.pending!.complete(PermissionGrant.granted);
    await tester.pumpUntilUiSettled();
    expect(find.byType(ConversationRoute), findsNothing);
    expect(permissions.requests, [false, true]);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('real background invalidates a late microphone grant', (
    tester,
  ) async {
    final permissions = EntryPermissions()
      ..pending = Completer<PermissionGrant>();
    await app(tester, permissions);
    await tapTask(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    permissions.pending!.complete(PermissionGrant.granted);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpUntilUiSettled();
    expect(find.byType(ConversationRoute), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'grant waits for popup resume and a later background cancels entry',
    (tester) async {
      final permissions = EntryPermissions()
        ..pending = Completer<PermissionGrant>();
      await app(tester, permissions);
      await tapTask(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      permissions.pending!.complete(PermissionGrant.granted);
      await tester.pump();
      expect(find.byType(ConversationRoute), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpUntilUiSettled();
      expect(find.byType(ConversationRoute), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'explicit settings survives settings background then reads real grant',
    (tester) async {
      final permissions = EntryPermissions()
        ..current = PermissionGrant.blocked
        ..settingsReturn = Completer<void>();
      await app(tester, permissions);
      await tapTask(tester);
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('去设置'));
      await tester.pumpUntilUiSettled();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byType(ConversationRoute), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      permissions.settingsReturn!.complete();
      await tester.pumpUntilUiSettled();
      expect(find.byType(ConversationRoute), findsOneWidget);
      expect(permissions.settings, 1);
      expect(permissions.requests, [false, false]);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('background during settings permission read cannot enter later', (
    tester,
  ) async {
    final permissions = EntryPermissions()
      ..current = PermissionGrant.blocked
      ..settingsReturn = Completer<void>()
      ..settingsRead = Completer<PermissionGrant>();
    await app(tester, permissions);
    await tapTask(tester);
    await tester.pumpUntilUiSettled();
    await tester.tap(find.text('去设置'));
    await tester.pumpUntilUiSettled();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    permissions.settingsReturn!.complete();
    await tester.pump();
    expect(permissions.requests, [false, false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    permissions.settingsRead!.complete(PermissionGrant.granted);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpUntilUiSettled();
    expect(find.byType(ConversationRoute), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'blocked microphone opens settings only after explicit confirmation',
    (tester) async {
      final permissions = EntryPermissions()..current = PermissionGrant.blocked;
      await app(tester, permissions);
      await tapTask(tester);
      await tester.pumpUntilUiSettled();
      expect(find.byType(ConversationRoute), findsNothing);
      expect(permissions.settings, 0);
      await tester.tap(find.text('去设置'));
      await tester.pumpUntilUiSettled();
      expect(permissions.settings, 1);
      expect(permissions.requests, [false, false]);
      expect(find.byType(ConversationRoute), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
