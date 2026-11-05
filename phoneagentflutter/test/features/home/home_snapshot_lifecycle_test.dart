import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import '../../support/apology_provider_fixture.dart';
import 'home_snapshot_readiness_test.dart'
    show SnapshotStore, SnapshotNetwork, snapshotRepository, publishedHome;

void main() {
  test(
    'ENTRY-03 formal home repository is replaced on account epoch change',
    () async {
      final epoch = StateProvider<int>((ref) => 1);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(environment: 'test', apiBaseUrl: ''),
          ),
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
        ],
      );
      addTearDown(container.dispose);
      final keep = container.listen(homeRepositoryProvider, (_, __) {});
      addTearDown(keep.close);
      final old = keep.read();
      container.read(epoch.notifier).state = 2;
      await container.pump();
      expect(keep.read(), isNot(same(old)));
    },
  );

  test(
    'ENTRY-02 background transport failure is consumed without replacing valid cache',
    () async {
      final store = SnapshotStore(cached: publishedHome());
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      addTearDown(repo.close);
      final snapshot = await repo.load();
      await network.started.future;
      network.responses.single.completeError(
        StateError('synthetic network failure'),
      );
      await repo.refreshPublished();
      expect(repo.loadFailed, isTrue);
      expect(snapshot.version, 'v1');
      expect(store.writes, 0);
    },
  );

  test(
    'ENTRY-03 corrupted cache falls back to complete bundled snapshot',
    () async {
      final store = SnapshotStore()..data['published'] = '{invalid';
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      addTearDown(repo.close);
      final snapshot = await repo.load();
      expect(snapshot.builtin, isTrue);
      expect(
        snapshot.cards.singleWhere((c) => c.id == 'restaurant_booking').opening,
        '想订哪家餐厅？告诉我时间和人数就行，有其他要求也可以一起说。',
      );
      await network.started.future;
      network.complete(publishedHome(), status: 500);
      await repo.refreshPublished();
      expect(store.writes, 0);
    },
  );

  test(
    'ENTRY-02 slow cache write neither blocks old snapshot nor creates parallel refreshes',
    () async {
      final store = SnapshotStore(cached: publishedHome())
        ..writeGate = Completer<void>();
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      addTearDown(repo.close);
      final old = await repo.load();
      expect(old.version, 'v1');
      await network.started.future;
      network.complete(publishedHome(version: 'v2', opening: '下一次开场'));
      await store.publishedWriteStarted.future;
      final fresh = await repo.load();
      expect(fresh.version, 'v2');
      expect(old.cards.single.opening, '缓存正式开场');
      expect(fresh.cards.single.opening, '下一次开场');
      expect(network.requests, hasLength(1));
      store.writeGate!.complete();
      await repo.refreshPublished();
      expect((await repo.load()).version, 'v2');
      expect(jsonDecode(store.data['published']!)['etag'], 'new-etag');
    },
  );

  test(
    'ENTRY-03 closed repository ignores late configuration response',
    () async {
      final store = SnapshotStore(cached: publishedHome());
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      await repo.load();
      await network.started.future;
      final refresh = repo.refreshPublished();
      repo.close();
      network.complete(publishedHome(version: 'old-account-late'));
      await refresh;
      expect(store.writes, 0);
      expect(
        jsonDecode(store.data['published']!)['data']['configVersion'],
        'v1',
      );
    },
  );

  test(
    'ENTRY-02 malformed background snapshot retains complete cache',
    () async {
      final store = SnapshotStore(cached: publishedHome());
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      addTearDown(repo.close);
      final old = await repo.load();
      await network.started.future;
      network.complete(publishedHome(version: 'bad', opening: ''));
      await repo.refreshPublished();
      expect(repo.loadFailed, isTrue);
      expect(store.writes, 0);
      expect(old.cards.single.opening, '缓存正式开场');
      expect(
        jsonDecode(store.data['published']!)['data']['configVersion'],
        'v1',
      );
    },
  );

  testWidgets(
    'ENTRY-01/02 cache read pending click freezes opening and real voice host narrates once',
    (t) async {
      final store = SnapshotStore()..readGate = Completer<String?>();
      final network = SnapshotNetwork();
      final repo = snapshotRepository(store, network);
      final home = HomeController(repo);
      addTearDown(() {
        home.dispose();
        repo.close();
      });
      unawaited(home.refresh());
      ConversationEntry? entry;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              state: home.state,
              modelName: '合成模型',
              onModels: () {},
              onRefresh: home.refresh,
              onEntry: (card) => entry = ConversationEntry(
                sessionId: 'cold-cache-entry',
                title: card.title,
                skillId: card.skillId,
                opening: card.opening,
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('skill-restaurant_booking')));
      const opening = '想订哪家餐厅？告诉我时间和人数就行，有其他要求也可以一起说。';
      expect(entry!.opening, opening);
      expect(entry!.skillId, 'restaurant_booking');
      expect(
        network.requests,
        isEmpty,
        reason: 'cached storage is still pending',
      );

      final fixture = ApologyProviderFixture(entry!);
      addTearDown(fixture.dispose);
      await fixture.open(t);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: Scaffold(
              body: ConversationVoiceHost(
                entry: entry!,
                builder: (_) => Text(entry!.opening),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(fixture.players.single.sentences, [opening]);
      store.readGate!.complete(null);
      await t.pumpAndSettle();
      expect(network.responses, hasLength(1));
      network.complete(publishedHome(version: 'v2', opening: '下一任务开场'));
      await t.pumpAndSettle();
      expect(home.state.config.version, 'v2');
      expect(find.text(opening), findsOneWidget);
      expect(fixture.players.single.sentences, [opening]);
      expect(
        fixture.container
            .read(conversationControllerProvider(entry!))
            .entry
            .opening,
        opening,
      );
      fixture.container
          .read(conversationControllerProvider(entry!).notifier)
          .close();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
