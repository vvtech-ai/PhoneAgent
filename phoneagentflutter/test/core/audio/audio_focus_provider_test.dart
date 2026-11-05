import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/audio_focus_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_audio_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

void main() {
  test('login changes retain same coordinator until hardware stops', () async {
    final epoch = StateProvider<int>((_) => 1);
    final journal = DiagnosticJournal(_Store());
    addTearDown(journal.close);
    final container = ProviderContainer(
      overrides: [
        loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
        diagnosticJournalProvider.overrideWithValue(journal),
      ],
    );
    addTearDown(container.dispose);
    final focus = container.read(audioPlaybackFocusProvider);
    final gate = Completer<void>();
    final old = await focus.acquire(
      owner: 'old',
      isCurrent: () => true,
      stop: (_) => gate.future,
    );
    container.read(epoch.notifier).state = 2;
    await container.pump();
    expect(container.read(audioPlaybackFocusProvider), same(focus));
    expect(focus.owns(old), isTrue);
    final next = focus.acquire(
      owner: 'new',
      isCurrent: () => true,
      stop: (_) async {},
    );
    gate.complete();
    expect((await next).owner, 'new');
  });

  test(
    'formal scoped journals retain late stops across account changes',
    () async {
      final journals = <String, DiagnosticJournal>{};
      final container = ProviderContainer(
        overrides: [
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
      await session.accept(_login('account-a'));
      final focus = container.read(audioPlaybackFocusProvider);
      final gate = Completer<void>();
      final old = await focus.acquire(
        owner: 'recording',
        isCurrent: () => true,
        stop: (_) => gate.future,
      );
      final a = container.read(diagnosticJournalProvider);
      await session.signOut();
      await session.accept(_login('account-b'));
      await container.pump();
      expect(container.read(audioPlaybackFocusProvider), same(focus));
      expect(focus.owns(old), isTrue);
      final b = container.read(diagnosticJournalProvider);
      final next = focus.acquire(
        owner: 'clone-preview',
        isCurrent: () => true,
        stop: (_) async {},
      );
      gate.complete();
      focus.release(await next);
      final aEvents = (await a.snapshot()).events;
      final bEvents = (await b.snapshot()).events;
      expect(aEvents.last.audio!.stage, DiagnosticAudioStage.release);
      expect(
        aEvents.every((e) => e.audio!.owner == DiagnosticAudioOwner.recording),
        isTrue,
      );
      expect(bEvents.length, 3);
      expect(
        bEvents.every(
          (e) => e.audio!.owner == DiagnosticAudioOwner.clonePreview,
        ),
        isTrue,
      );
      for (final entry in journals.entries) {
        if (entry.key.endsWith('|signed-out')) {
          expect((await entry.value.snapshot()).events, isEmpty);
        }
      }
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
