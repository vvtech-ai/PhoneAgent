import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/home/data/dio_home_repository.dart';
import 'package:phone_agent/features/home/data/home_config_mapper.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'home_repository_test.dart' show fixture;

Map<String, dynamic> publishedHome({
  String version = 'v1',
  String opening = '缓存正式开场',
}) => fixture()
  ..['configVersion'] = version
  ..['skillRefs'] = [
    {'id': 'test_skill', 'opening': opening},
  ];

class SnapshotStore implements HomeLocalStore {
  SnapshotStore({Map<String, dynamic>? cached}) {
    if (cached != null) {
      data['published'] = jsonEncode({'data': cached, 'etag': 'old-etag'});
    }
  }
  final data = <String, String>{};
  Completer<String?>? readGate;
  Completer<void>? writeGate;
  Completer<void> written = Completer<void>();
  final publishedWriteStarted = Completer<void>();
  int writes = 0;
  @override
  Future<String?> read(String key) async =>
      key == 'published' && readGate != null ? readGate!.future : data[key];
  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (key == 'published' && !publishedWriteStarted.isCompleted) {
      publishedWriteStarted.complete();
    }
    if (writeGate != null) await writeGate!.future;
    data[key] = value;
    if (key == 'published' && !written.isCompleted) written.complete();
  }
}

class SnapshotNetwork implements HttpClientAdapter {
  final started = Completer<void>();
  final responses = <Completer<ResponseBody>>[];
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    requests.add(options);
    final response = Completer<ResponseBody>();
    responses.add(response);
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  void complete(Map<String, dynamic> data, {int status = 200}) =>
      responses.last.complete(
        ResponseBody.fromString(
          jsonEncode({'code': 0, 'data': data}),
          status,
          headers: {
            'etag': ['new-etag'],
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
  @override
  void close({bool force = false}) {}
}

DioHomeRepository snapshotRepository(
  SnapshotStore store,
  SnapshotNetwork network,
) => DioHomeRepository(
  AppConfig.parse(environment: 'test', apiBaseUrl: 'https://example.test/'),
  store,
  client: Dio()..httpClientAdapter = network,
);

class SlowSloganHome implements HomeRepository {
  final slogan = Completer<HomeSlogan>();
  @override
  Future<HomeConfig> load() async =>
      const HomeConfig('cache', [HomeSlogan('s', '缓存标题', '缓存说明')], []);
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) => slogan.future;
}

void main() {
  test(
    'ENTRY-02 incomplete enabled ordinary skill is rejected as an invalid snapshot',
    () {
      final mapper = HomeConfigMapper(Uri.parse('https://example.test/'));
      expect(
        () => mapper.parse(fixture()..remove('skillRefs')),
        throwsFormatException,
      );
      final valid = publishedHome();
      expect(mapper.parse(valid).cards.single.opening, '缓存正式开场');
    },
  );

  test(
    'ENTRY-01 every immediately clickable bundled ordinary skill has its exact v66 opening',
    () {
      final controller = HomeController(SlowSloganHome());
      final expected = {
        'restaurant_booking': '想订哪家餐厅？告诉我时间和人数就行，有其他要求也可以一起说。',
        'meeting_notification': '要通知谁、几点在哪开会？我来帮你打电话通知。',
        'business_event_invitation': '请告诉我或上传活动内容、受邀联系人名单及相关资料。我来打电话邀请。',
        'sales_recommendation': '请告诉我或上传推广信息、联系人相关资料。我来打电话联系。',
        'meeting_notification_v2': '请告诉我或上传会议通知、受邀联系人名单及相关资料。我来打电话邀请。',
      };
      for (final card in controller.state.config.cards.where(
        (c) => c.canEnter('1.0.52'),
      )) {
        expect(
          card.opening,
          expected[card.skillId],
          reason: 'complete bundled ${card.skillId}',
        );
      }
      controller.dispose();
    },
  );

  test(
    'ENTRY-02 valid cache is published before the network responds',
    () async {
      final network = SnapshotNetwork();
      final store = SnapshotStore(cached: publishedHome());
      final repo = snapshotRepository(store, network);
      addTearDown(repo.close);
      final controller = HomeController(repo);
      addTearDown(controller.dispose);
      unawaited(controller.refresh());
      await network.started.future;
      expect(controller.state.config.version, 'v1');
      expect(controller.state.config.cards.single.opening, '缓存正式开场');
      expect(controller.state.loading, isFalse);
      network.complete(publishedHome(version: 'v2'));
      await store.written.future;
    },
  );

  test(
    'ENTRY-02 cached snapshot remains usable after background failure',
    () async {
      final network = SnapshotNetwork();
      final repo = snapshotRepository(
        SnapshotStore(cached: publishedHome()),
        network,
      );
      addTearDown(repo.close);
      HomeConfig? loaded;
      final load = repo.load().then((value) => loaded = value);
      await network.started.future;
      network.complete(publishedHome(), status: 500);
      await load;
      expect(loaded!.version, 'v1');
      expect(loaded!.cards.single.opening, '缓存正式开场');
    },
  );

  test(
    'ENTRY-01 snapshot publication does not wait for slogan persistence',
    () async {
      final repository = SlowSloganHome();
      final controller = HomeController(repository);
      unawaited(controller.refresh());
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.config.version, 'cache');
      expect(controller.state.loading, isFalse);
      controller.dispose();
      repository.slogan.complete(const HomeSlogan('s', '缓存标题', '缓存说明'));
      await Future<void>.delayed(Duration.zero);
    },
  );
}
