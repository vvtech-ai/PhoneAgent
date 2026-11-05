import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/native_crash_host.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/native_crash_importer.dart';
import 'package:phone_agent/features/app_logs/data/device_native_crash_port.dart';

import 'native_crash_importer_test.dart'
    show MemoryCrashJournalStore, FakeCrashPort, row, scopeA;

void main() {
  testWidgets(
    'normal host follows scope; late old data persists only to old journal',
    (tester) async {
      final gate = Completer<List<NativeCrashSummary>>();
      final port = FakeCrashPort()..readGate = gate;
      final journals = <String, DiagnosticJournal>{};
      DiagnosticJournal factory(String scope) => journals.putIfAbsent(
        scope,
        () => DiagnosticJournal(MemoryCrashJournalStore()),
      );
      final container = ProviderContainer(
        overrides: [
          nativeCrashPortProvider.overrideWithValue(port),
          diagnosticStorageScopeProvider.overrideWithValue(
            'dev|https://example.test/|account-a',
          ),
          diagnosticJournalFactoryProvider.overrideWithValue(factory),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NativeCrashHost(child: SizedBox()),
        ),
      );
      await tester.pump();
      container.updateOverrides([
        nativeCrashPortProvider.overrideWithValue(port),
        diagnosticStorageScopeProvider.overrideWithValue(
          'dev|https://example.test/|account-b',
        ),
        diagnosticJournalFactoryProvider.overrideWithValue(factory),
      ]);
      await tester.pump();
      gate.complete([NativeCrashSummary.fromMap(row(scopeA), scopeA)]);
      await tester.pump();
      expect(
        (await journals['dev|https://example.test/|account-a']!.snapshot())
            .events
            .length,
        1,
      );
      expect(
        (await journals['dev|https://example.test/|account-b']!.snapshot())
            .events,
        isEmpty,
      );
      expect(
        port.bindings.last,
        nativeCrashScope('dev|https://example.test/|account-b'),
      );
      final beforeResume = port.bindings.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(port.bindings.length, beforeResume + 1);
      await tester.pumpWidget(const SizedBox());
      expect(port.bindings.last, isNull);
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'desktop does not create native crash port or read account storage',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diagnosticStorageScopeProvider.overrideWith(
              (ref) => throw StateError('must not read'),
            ),
          ],
          child: const NativeCrashHost(child: SizedBox()),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
