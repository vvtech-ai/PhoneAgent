import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_entry_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'invite_fakes.dart';

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

class _SessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  test(
    'provider records safe stages without changing controller on account change',
    () async {
      final journals = <String, DiagnosticJournal>{};
      final device = FakeInviteDevice();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test/',
            ),
          ),
          inviteDeviceProvider.overrideWithValue(device),
          inviteStoreProvider.overrideWithValue(MemoryInviteStore()),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          inviteLinkPolicyProvider.overrideWithValue(
            const InviteLinkPolicy(
              host: 'example.test',
              path: '/invite/',
              scheme: 'phoneagent-test',
            ),
          ),
          diagnosticJournalFactoryProvider.overrideWithValue(
            (scope) =>
                journals.putIfAbsent(scope, () => DiagnosticJournal(_Store())),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(device.received.close);
      final entry = container.read(inviteEntryProvider.notifier);
      final publicResolver = container.read(inviteResolverProvider);
      await Future<void>.delayed(Duration.zero);
      entry.receive('https://invalid.test/invite/?code=ABCD');
      final session = container.read(sessionControllerProvider.notifier);
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          inviteRequired: false,
          accountId: 'synthetic-a',
          accessToken: 'synthetic-token',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(inviteEntryProvider.notifier), same(entry));
      expect(container.read(inviteResolverProvider), same(publicResolver));
      entry.receive('https://example.test/invite/?code=EFGH');
      final a = container.read(diagnosticJournalProvider);
      final events = (await a.snapshot()).events;
      expect(events.map((e) => e.operation), [
        DiagnosticOperation.inviteReceived,
        DiagnosticOperation.inviteExistingAccount,
      ]);
      final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
      for (final secret in [
        'EFGH',
        'ABCD',
        'example.test',
        '13800000000',
        'synthetic-token',
        'synthetic-a',
      ]) {
        expect(encoded, isNot(contains(secret)));
      }
      for (final event in events) {
        expect(event.toJson().keys.toSet(), {
          'operation',
          'result',
          'time',
          'statusCode',
          'elapsedMs',
        });
        expect(
          DiagnosticEvent.fromJson(event.toJson()).operation,
          event.operation,
        );
      }
      await session.signOut();
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          inviteRequired: false,
          accountId: 'synthetic-b',
          accessToken: 'synthetic-token',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(inviteEntryProvider.notifier), same(entry));
      expect(container.read(inviteResolverProvider), same(publicResolver));
      expect(
        (await container.read(diagnosticJournalProvider).snapshot()).events,
        isEmpty,
      );
      expect((await a.snapshot()).events.length, 2);
    },
  );
  test(
    'queued, rejected and failed stream are distinct; observer failure is harmless',
    () async {
      final device = FakeInviteDevice();
      final pending = PendingInviteController(MemoryInviteStore());
      final events = <InviteEntryEvent>[];
      final entry = InviteEntryController(
        device,
        const InviteLinkPolicy(
          host: 'example.test',
          path: '/invite/',
          scheme: '',
        ),
        pending,
        onEvent: events.add,
      );
      await entry.start();
      entry.receive('https://example.test/invite/?code=ABCD');
      expect(events, [InviteEntryEvent.received, InviteEntryEvent.queued]);
      entry.session(ready: true, signedIn: false);
      await Future<void>.delayed(Duration.zero);
      expect(events.last, InviteEntryEvent.registrationDispatched);
      device.received.addError(StateError('synthetic'));
      await Future<void>.delayed(Duration.zero);
      expect(events.last, InviteEntryEvent.streamFailed);
      entry.receive('https://invalid.test/invite/?code=ABCD');
      expect(events.last, InviteEntryEvent.rejected);
      entry.dispose();
      final unobserved = InviteEntryController(
        device,
        const InviteLinkPolicy(
          host: 'example.test',
          path: '/invite/',
          scheme: '',
        ),
        pending,
        onEvent: (_) => throw StateError('diagnostics'),
      );
      unobserved.session(ready: true, signedIn: true);
      unobserved.receive('https://example.test/invite/?code=EFGH');
      expect(unobserved.state, '本次邀请奖励仅限新用户');
      unobserved.dispose();
      await Future<void>.delayed(Duration.zero);
      pending.dispose();
      await device.received.close();
    },
  );
}
