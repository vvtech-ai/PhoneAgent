import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/task_draft_cleanup.dart';
import 'package:phone_agent/app/task_draft_cleanup_providers.dart';
import 'package:phone_agent/features/conversation/data/drafts/task_draft_account_store.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/app/session_navigation_host.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import '../../../tool/previews/auth_scenario.dart';
import '../tasks/task_pagination_test.dart' show Pages, page, row;

void main() {
  test('token refresh retains account cleanup owner', () async {
    final session = SessionController(AuthScenario(AuthScenarioKind.direct));
    await session.accept(
      const LoginOutcome(
        phone: '13800000000',
        accountId: 'synthetic',
        accessToken: 'synthetic-token',
        inviteRequired: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [sessionControllerProvider.overrideWith((ref) => session)],
    );
    final subscription = container.listen(
      taskDraftAccountStoreProvider,
      (_, _) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    final first = container.read(taskDraftAccountStoreProvider);
    await session.replaceToken(session.credentials!, 'synthetic-next');
    expect(
      identical(container.read(taskDraftAccountStoreProvider), first),
      isTrue,
    );
  });

  testWidgets(
    'local cleanup failure cannot leave logout stuck on a blank page',
    (tester) async {
      final session = SessionController(AuthScenario(AuthScenarioKind.direct));
      addTearDown(session.dispose);
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'synthetic',
          accessToken: 'synthetic-token',
          inviteRequired: false,
        ),
      );
      var failures = 0;
      final cleanup = TaskDraftCleanup(
        _FailingDraftStore(),
        onFailure: () => failures++,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SessionNavigationHost(
            session: session,
            epoch: session.credentials!.epoch,
            onReleased: cleanup.clearAccount,
            child: const SizedBox(),
          ),
        ),
      );
      final logout = session.signOut();
      await tester.pump();
      await tester.pump();
      await logout;
      expect(session.state.phase, SessionPhase.signedOut);
      expect(failures, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test('local cleanup failure does not reverse remote task deletion', () async {
    final repo = Pages();
    var failures = 0;
    final cleanup = TaskDraftCleanup(
      _FailingDraftStore(),
      onFailure: () => failures++,
    );
    final owner = TaskController(
      repo,
      afterHide: (task) => cleanup.clearTask(task.sessionId!),
    );
    addTearDown(owner.dispose);
    final deleting = owner.hide(row('one'));
    await Future<void>.delayed(Duration.zero);
    repo.responses.last.complete(page([]));
    expect(await deleting, isTrue);
    expect(failures, 1);
    expect(owner.state.notice, isEmpty);
  });
  testWidgets(
    'account cleanup waits for page disposal and logout waits for cleanup',
    (tester) async {
      final session = SessionController(AuthScenario(AuthScenarioKind.direct));
      addTearDown(session.dispose);
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'synthetic',
          accessToken: 'synthetic-token',
          inviteRequired: false,
        ),
      );
      final cleanup = Completer<void>();
      var disposed = false, entered = false, signedOut = false;
      bool? disposedAtCleanup;
      await tester.pumpWidget(
        MaterialApp(
          home: SessionNavigationHost(
            session: session,
            epoch: session.credentials!.epoch,
            onReleased: () {
              disposedAtCleanup = disposed;
              entered = true;
              return cleanup.future;
            },
            child: _Page(onDispose: () => disposed = true),
          ),
        ),
      );
      final logout = session.signOut().then((_) => signedOut = true);
      await tester.pump();
      await tester.pump();
      expect(entered, isTrue);
      expect(disposedAtCleanup, isTrue);
      expect(signedOut, isFalse);
      cleanup.complete();
      await logout;
      expect(signedOut, isTrue);
    },
  );

  test('task cleanup runs only after a successful remote deletion', () async {
    final repo = Pages();
    final cleaned = <String>[];
    final owner = TaskController(
      repo,
      afterHide: (task) async => cleaned.add(task.sessionId!),
    );
    addTearDown(owner.dispose);
    repo.mutation = Completer<void>();
    final deleting = owner.hide(row('one'));
    expect(cleaned, isEmpty);
    repo.mutation!.complete();
    await Future<void>.delayed(Duration.zero);
    repo.responses.last.complete(page([]));
    expect(await deleting, isTrue);
    expect(cleaned, ['one']);
    repo.mutation = Completer<void>();
    final failed = owner.hide(row('two'));
    repo.mutation!.completeError(StateError('offline'));
    expect(await failed, isFalse);
    expect(cleaned, ['one']);
  });
}

class _Page extends StatefulWidget {
  const _Page({required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<_Page> createState() => _PageState();
}

class _FailingDraftStore extends TaskDraftAccountStore {
  _FailingDraftStore() : super(['test', 'https://test', 'synthetic']);
  @override
  Future<void> clearAccount() async => throw StateError('storage');
  @override
  Future<void> clearTask(String sessionId) async => throw StateError('storage');
}

class _PageState extends State<_Page> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
