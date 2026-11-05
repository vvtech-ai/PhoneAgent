import 'dart:convert';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/runtime_diagnostics_host.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_store.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/main.dart' as app;

void main() {
  testWidgets('current account is chosen at occurrence and survives storage', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final previous = FlutterError.onError;
    var forwards = 0;
    FlutterError.onError = (_) => forwards++;
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: 'dev',
            apiBaseUrl: 'https://example.test/api/',
          ),
        ),
        sessionStoreProvider.overrideWithValue(_SessionStore()),
      ],
    );
    try {
      final session = container.read(sessionControllerProvider.notifier);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RuntimeDiagnosticsHost(child: SizedBox()),
        ),
      );
      await tester.pump();
      final signedOut = container.read(diagnosticJournalProvider);
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('private')),
      );
      await session.accept(_login('account-a'));
      final accountA = container.read(diagnosticJournalProvider);
      FlutterError.reportError(
        FlutterErrorDetails(exception: ArgumentError('private')),
      );
      await session.signOut();
      await session.accept(_login('account-b'));
      final accountB = container.read(diagnosticJournalProvider);
      FlutterError.reportError(
        FlutterErrorDetails(exception: const FormatException('private')),
      );
      // Let immediate flush complete without advancing the 500ms timer and
      // inspect durable state before snapshot could itself flush the journal.
      await tester.pump();
      for (final entry in {
        'signed-out': DiagnosticFailureKind.state,
        'account-a': DiagnosticFailureKind.argument,
        'account-b': DiagnosticFailureKind.format,
      }.entries) {
        final stored = await SecureDiagnosticStore(
          'dev|https://example.test/api/|${entry.key}',
        ).read();
        final json = jsonDecode(stored!) as Map<String, dynamic>;
        expect(
          (json['events'] as List).single['failureKind'],
          entry.value.name,
        );
        expect(stored, isNot(contains('private')));
      }
      expect(
        (await signedOut.snapshot()).events.single.failureKind,
        DiagnosticFailureKind.state,
      );
      expect(
        (await accountA.snapshot()).events.single.failureKind,
        DiagnosticFailureKind.argument,
      );
      expect(
        (await accountB.snapshot()).events.single.failureKind,
        DiagnosticFailureKind.format,
      );
      final bundle = await ZipLogRepository(
        accountB,
        uploadBundle: (_) async {
          fail('preparing runtime logs must not upload');
        },
      ).prepare();
      final archive = ZipDecoder().decodeBytes(bundle.bytes, verify: true);
      final row = jsonDecode(
        utf8.decode(archive.files.single.content as List<int>),
      );
      expect(row['operation'], 'flutterFramework');
      expect(row['failureKind'], 'format');
      expect(forwards, 3);
      await tester.pumpWidget(const SizedBox());
      expect(FlutterError.onError, isNotNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
      FlutterError.onError = previous;
    }
  });

  testWidgets(
    'write failure is isolated; retry retains event and unmount restores hooks',
    (tester) async {
      final previous = FlutterError.onError;
      final previousUnhandled = PlatformDispatcher.instance.onError;
      var forwards = 0;
      void handler(FlutterErrorDetails _) => forwards++;
      FlutterError.onError = handler;
      final store = _FailingStore();
      final journal = DiagnosticJournal(store);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [diagnosticJournalProvider.overrideWithValue(journal)],
            child: const RuntimeDiagnosticsHost(child: SizedBox()),
          ),
        );
        FlutterError.reportError(
          FlutterErrorDetails(exception: StateError('private')),
        );
        await tester.pump();
        expect(forwards, 1);
        expect(store.writes, 1);
        expect(tester.takeException(), isNull);
        store.fail = false;
        await journal.flush();
        expect((await journal.snapshot()).events.length, 1);
        await tester.pumpWidget(const SizedBox());
        expect(FlutterError.onError, same(handler));
        expect(PlatformDispatcher.instance.onError, same(previousUnhandled));
      } finally {
        await tester.pumpWidget(const SizedBox());
        journal.close();
        await tester.pump();
        FlutterError.onError = previous;
      }
    },
  );

  testWidgets('normal main installs runtime host and retains login form', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final previous = FlutterError.onError;
    final previousUnhandled = PlatformDispatcher.instance.onError;
    try {
      await tester.runAsync(app.main);
      await tester.pumpAndSettle();
      expect(find.byType(RuntimeDiagnosticsHost), findsOneWidget);
      expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
      expect(find.byKey(const ValueKey('loginCode')), findsOneWidget);
      expect(FlutterError.onError, isNot(same(previous)));
      expect(
        PlatformDispatcher.instance.onError,
        isNot(same(previousUnhandled)),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(FlutterError.onError, same(previous));
      expect(PlatformDispatcher.instance.onError, same(previousUnhandled));
    }
  });
}

LoginOutcome _login(String account) => LoginOutcome(
  phone: '13800000000',
  accountId: account,
  inviteRequired: false,
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

class _FailingStore implements DiagnosticStore {
  bool fail = true;
  int writes = 0;
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    writes++;
    if (fail) throw StateError('synthetic-disk-error');
    value = text;
  }
}
