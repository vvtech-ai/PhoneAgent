import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'home_snapshot_readiness_test.dart'
    show SnapshotStore, SnapshotNetwork, snapshotRepository, publishedHome;

class _FailingPublishedStore extends SnapshotStore {
  _FailingPublishedStore() : super(cached: publishedHome());
  @override
  Future<void> write(String key, String value) {
    if (key == 'published') throw StateError('synthetic disk failure');
    return super.write(key, value);
  }
}

void main() {
  testWidgets('cold home applies a published update without tab navigation', (
    t,
  ) async {
    final store = SnapshotStore();
    final network = SnapshotNetwork();
    final repo = snapshotRepository(store, network);
    final home = HomeController(repo);
    addTearDown(() {
      home.dispose();
      repo.close();
    });
    final states = ValueNotifier(home.state);
    final remove = home.addListener((s) => states.value = s);
    addTearDown(() {
      remove();
      states.dispose();
    });
    unawaited(home.refresh());
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: states,
              builder: (_, state, __) => HomePage(
                state: state,
                modelName: '合成模型',
                onModels: () {},
                onRefresh: home.refresh,
                onEntry: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(network.requests, hasLength(1));
    network.complete(publishedHome(version: 'live-home'));
    await t.pumpAndSettle();
    expect(home.state.config.version, 'live-home');
    expect(find.text('测试'), findsOneWidget);
  });

  test(
    'cached home updates before slow disk persistence and keeps clicked snapshot',
    () async {
      final store = SnapshotStore(cached: publishedHome())
        ..writeGate = Completer<void>();
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      final home = HomeController(repo);
      addTearDown(() {
        home.dispose();
        repo.close();
      });
      await home.refresh();
      final clicked = home.state.config.cards.single;
      await network.started.future;
      network.complete(publishedHome(version: 'v2', opening: '下一任务开场'));
      await store.publishedWriteStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(home.state.config.version, 'v2');
      expect(clicked.opening, '缓存正式开场');
      expect(home.state.config.cards.single.opening, '下一任务开场');
      expect(network.requests, hasLength(1));
      store.writeGate!.complete();
      await repo.refreshPublished();
    },
  );

  test(
    'same config version with changed valid content still reaches current home',
    () async {
      final store = SnapshotStore(cached: publishedHome());
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      final home = HomeController(repo);
      addTearDown(() {
        home.dispose();
        repo.close();
      });
      await home.refresh();
      await network.started.future;
      network.complete(publishedHome(opening: '本版本更新后的开场'));
      await repo.refreshPublished();
      await Future<void>.delayed(Duration.zero);
      expect(home.state.config.cards.single.opening, '本版本更新后的开场');
    },
  );

  test('network update wins a slow initial cache read', () async {
    final store = SnapshotStore()..readGate = Completer<String?>();
    final network = SnapshotNetwork();
    final repo = snapshotRepository(store, network);
    final home = HomeController(repo);
    addTearDown(() {
      home.dispose();
      repo.close();
    });
    final load = home.refresh();
    final refresh = repo.refreshPublished();
    await network.started.future;
    network.complete(publishedHome(version: 'new-before-cache'));
    await refresh;
    store.readGate!.complete(null);
    await load;
    expect(home.state.config.version, 'new-before-cache');
  });

  test('disk write failure does not discard the valid online update', () async {
    final store = _FailingPublishedStore();
    final network = SnapshotNetwork();
    final repo = snapshotRepository(store, network);
    final home = HomeController(repo);
    addTearDown(() {
      home.dispose();
      repo.close();
    });
    await home.refresh();
    await network.started.future;
    network.complete(publishedHome(version: 'live-without-disk'));
    await repo.refreshPublished();
    expect(home.state.config.version, 'live-without-disk');
    expect(store.data['published'], isNot(contains('live-without-disk')));
    expect(repo.loadFailed, false);
  });

  test(
    '304 and failed responses preserve the current valid snapshot',
    () async {
      for (final status in [304, 500]) {
        final network = SnapshotNetwork();
        final repo = snapshotRepository(
          SnapshotStore(cached: publishedHome()),
          network,
        );
        final home = HomeController(repo);
        await home.refresh();
        final old = home.state.config;
        await network.started.future;
        expect(network.requests.single.headers['If-None-Match'], 'old-etag');
        network.complete(
          publishedHome(version: 'must-not-apply'),
          status: status,
        );
        await repo.refreshPublished();
        expect(home.state.config, same(old));
        home.dispose();
        repo.close();
      }
    },
  );

  test('disposed account ignores a late published response', () async {
    final store = SnapshotStore(cached: publishedHome());
    final network = SnapshotNetwork();
    final repo = snapshotRepository(store, network);
    final home = HomeController(repo);
    await home.refresh();
    await network.started.future;
    final pending = repo.refreshPublished();
    home.dispose();
    repo.close();
    network.complete(publishedHome(version: 'old-account-late'));
    await pending;
    expect(store.data['published'], isNot(contains('old-account-late')));
  });
}
