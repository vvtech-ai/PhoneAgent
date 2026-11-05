import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_auth_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

void main() {
  test(
    'formal gateway survives identity changes; journals remain scoped',
    () async {
      final journals = <String, DiagnosticJournal>{};
      final container = ProviderContainer(
        overrides: [
          // Unconfigured transport proves this test cannot send an SMS.
          appConfigProvider.overrideWithValue(
            AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          diagnosticJournalFactoryProvider.overrideWithValue(
            (scope) =>
                journals.putIfAbsent(scope, () => DiagnosticJournal(_Store())),
          ),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final gateway = container.read(authGatewayProvider);
      expect(journals, isEmpty); // No eagerly watched session/journal cycle.
      await expectLater(
        gateway.sendCode('13800000000'),
        throwsA(AuthFailure.unavailable),
      );
      await session.accept(_login('account-a'));
      expect(container.read(authGatewayProvider), same(gateway));
      await expectLater(
        gateway.login(
          const LoginSubmission(phone: '13800000000', code: '1234'),
        ),
        throwsA(AuthFailure.unavailable),
      );
      await session.signOut();
      await session.accept(_login('account-b'));
      expect(container.read(authGatewayProvider), same(gateway));
      final b = container.read(diagnosticJournalProvider);
      expect((await b.snapshot()).events, isEmpty);
      final anonymous = journals['dev|null|signed-out']!;
      final accountA = journals['dev|null|account-a']!;
      expect(
        (await anonymous.snapshot()).events.single.operation,
        DiagnosticOperation.authSendCode,
      );
      expect(
        (await accountA.snapshot()).events.single.operation,
        DiagnosticOperation.authLogin,
      );
      await expectLater(
        gateway.sendCode('13800000000'),
        throwsA(AuthFailure.unavailable),
      );
      final event = (await b.snapshot()).events.single;
      expect(event.auth!.outcome, DiagnosticAuthOutcome.unavailable);
      expect(event.statusCode, 0);
      // No moving old anonymous/account-A diagnostics into account B.
      expect((await anonymous.snapshot()).events.length, 1);
      expect((await accountA.snapshot()).events.length, 1);
    },
  );

  test(
    'formal diagnostic factory failure does not replace authentication failure',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          diagnosticJournalFactoryProvider.overrideWithValue(
            (_) => throw StateError('synthetic storage failure'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(authGatewayProvider).sendCode('13800000000'),
        throwsA(AuthFailure.unavailable),
      );
    },
  );
}

LoginOutcome _login(String id) => LoginOutcome(
  phone: '13800000000',
  inviteRequired: false,
  accountId: id,
  accessToken: 'synthetic-token',
);

class _SessionStore implements SessionStore {
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async => value = session;
  @override
  Future<void> clear() async => value = null;
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async => value = text;
}
