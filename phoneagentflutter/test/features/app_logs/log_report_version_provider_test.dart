import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/app_logs/presentation/controller/log_report_controller.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vvtech.phone_agent/app_info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DiagnosticJournal journal;
  late ProviderContainer container;
  late _Adapter adapter;
  late Future<Map<String, Object?>> Function() readMetadata;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    readMetadata = () async => {
      'packageName': 'com.vvtech.aiassistant.test',
      'versionName': '1.0.52',
      'versionCode': 45,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, anyOf('read', 'readEnvironment'));
      final app = await readMetadata();
      if (call.method == 'read') return app;
      final ios = debugDefaultTargetPlatformOverride == TargetPlatform.iOS;
      return {
        'appVersionName': app['versionName'],
        'appVersionCode': app['versionCode'],
        'osName': ios ? 'iOS' : 'Android',
        'osVersion': ios ? '17.6' : '14',
        if (!ios) 'apiLevel': 34,
        'deviceBrand': ios ? 'Apple' : 'google',
        'deviceManufacturer': ios ? 'Apple' : 'Google',
        'deviceModel': ios ? 'iPhone' : 'Pixel 8',
        'deviceHardwareModel': ios ? 'iPhone16,1' : 'shiba',
      };
    });
    journal = DiagnosticJournal(_Store());
    journal.record(
      DiagnosticEvent(
        operation: DiagnosticOperation.agentStream,
        result: DiagnosticResult.failed,
        elapsedMs: 37,
      ),
    );
    adapter = _Adapter();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: 'test',
            apiBaseUrl: 'https://example.test/aiassistant-api/',
          ),
        ),
        sessionStoreProvider.overrideWithValue(_SessionStore()),
        diagnosticJournalProvider.overrideWithValue(journal),
        accountApiProvider.overrideWith((ref) {
          ref.watch(loginEpochProvider);
          final api = AccountApi(
            ref.watch(appConfigProvider),
            ref.watch(sessionControllerProvider.notifier),
            client: Dio()..httpClientAdapter = adapter,
          );
          ref.onDispose(api.close);
          return api;
        }),
      ],
    );
    container.read(sessionControllerProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() {
    container.dispose();
    journal.close();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  LogReportController controller() {
    container.listen(logEntryControllerProvider, (_, _) {});
    return container.read(logEntryControllerProvider.notifier);
  }

  for (final fixture in [
    (TargetPlatform.android, '1.0.52', 45),
    (TargetPlatform.iOS, '1.7.3', 82),
  ]) {
    test('formal upload reports installed ${fixture.$1.name} version', () async {
      debugDefaultTargetPlatformOverride = fixture.$1;
      readMetadata = () async => {
        'packageName': fixture.$1 == TargetPlatform.iOS
            ? 'com.chaken.phoneagent.test'
            : 'com.vvtech.aiassistant.test',
        'versionName': fixture.$2,
        'versionCode': fixture.$3,
      };
      final report = controller();
      await report.prepare();
      final bundle = report.snapshot.bundle!;
      adapter.reply(bundle);
      await report.upload();

      final request = adapter.requests.single;
      final data = request.data as FormData;
      expect(Map.fromEntries(data.fields), {
        'accountId': 'synthetic-account',
        'deviceInfo':
            'Flutter ${fixture.$1.name} / ${fixture.$2}(${fixture.$3}); '
            '${fixture.$1 == TargetPlatform.iOS ? 'iOS 17.6' : 'Android 14 (API 34)'}; '
            'brand=${fixture.$1 == TargetPlatform.iOS ? 'Apple' : 'google'}; '
            'manufacturer=${fixture.$1 == TargetPlatform.iOS ? 'Apple' : 'Google'}; '
            'model=${fixture.$1 == TargetPlatform.iOS ? 'iPhone' : 'Pixel 8'}; '
            'hardware=${fixture.$1 == TargetPlatform.iOS ? 'iPhone16,1' : 'shiba'}',
      });
      expect(request.uri.path, '/aiassistant-api/api/logs/upload');
      expect(request.headers['X-Account-Id'], 'synthetic-account');
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      expect(data.files.single.key, 'file');
      expect(data.files.single.value.filename, bundle.fileName);
      expect(data.files.single.value.length, bundle.bytes.length);
      final archive = ZipDecoder().decodeBytes(bundle.bytes, verify: true);
      expect(archive.files.map((file) => file.name), [
        'diagnostics.jsonl',
        'device-environment.json',
      ]);
      final environment =
          jsonDecode(utf8.decode(archive.files.last.content as List<int>))
              as Map<String, dynamic>;
      expect(environment['available'], isTrue);
      expect(environment['appVersion'], fixture.$2);
      expect(
        environment['osVersion'],
        fixture.$1 == TargetPlatform.iOS ? '17.6' : '14',
      );
      expect(
        environment['hardwareModel'],
        fixture.$1 == TargetPlatform.iOS ? 'iPhone16,1' : 'shiba',
      );
      final event =
          jsonDecode(utf8.decode(archive.files.first.content as List<int>))
              as Map<String, dynamic>;
      expect(event['elapsedMs'], 37);
      expect(report.snapshot.phase, LogReportPhase.success);
      expect((await journal.snapshot()).events, isEmpty);
    });
  }

  test(
    'ZIP environment and upload metadata stay fixed across a failed upload retry',
    () async {
      final report = controller();
      await report.prepare();
      final bundle = report.snapshot.bundle!;
      final original = sha256.convert(bundle.bytes).toString();
      readMetadata = () async =>
          throw PlatformException(code: 'later-read-must-not-happen');
      adapter.status = 503;
      await report.upload();
      expect(report.snapshot.phase, LogReportPhase.failed);
      expect(adapter.requests, hasLength(1));
      final firstInfo = Map.fromEntries(
        (adapter.requests.first.data as FormData).fields,
      )['deviceInfo'];
      expect(firstInfo, contains('Pixel 8'));
      adapter.status = 200;
      adapter.reply(bundle);
      await report.upload();
      expect(report.snapshot.phase, LogReportPhase.success);
      expect(sha256.convert(bundle.bytes).toString(), original);
      expect(
        Map.fromEntries(
          (adapter.requests.last.data as FormData).fields,
        )['deviceInfo'],
        firstInfo,
      );
      final zip = ZipDecoder().decodeBytes(bundle.bytes);
      final metadata =
          jsonDecode(utf8.decode(zip.files.last.content as List<int>))
              as Map<String, dynamic>;
      expect(metadata['model'], 'Pixel 8');
      expect(metadata.keys, isNot(contains('accountId')));
    },
  );

  test(
    'a late recovered device snapshot is fixed before the first network attempt',
    () async {
      readMetadata = () async =>
          throw PlatformException(code: 'temporarily-unavailable');
      final report = controller();
      await report.prepare();
      final bundle = report.snapshot.bundle!;
      final checksum = sha256.convert(bundle.bytes).toString();
      final zip = ZipDecoder().decodeBytes(bundle.bytes);
      expect(
        jsonDecode(
          utf8.decode(zip.files.last.content as List<int>),
        )['available'],
        isFalse,
      );
      readMetadata = () async => {'versionName': '1.0.52', 'versionCode': 45};
      adapter.status = 503;
      await report.upload();
      expect(adapter.requests, hasLength(1));
      final info = Map.fromEntries(
        (adapter.requests.single.data as FormData).fields,
      )['deviceInfo'];
      readMetadata = () async =>
          throw PlatformException(code: 'must-not-read-again');
      adapter.status = 200;
      adapter.reply(bundle);
      await report.upload();
      expect(report.snapshot.phase, LogReportPhase.success);
      expect(
        Map.fromEntries(
          (adapter.requests.last.data as FormData).fields,
        )['deviceInfo'],
        info,
      );
      expect(sha256.convert(bundle.bytes).toString(), checksum);
    },
  );
  test(
    'metadata failure retains the ZIP without uploading a guessed version',
    () async {
      readMetadata = () async => throw PlatformException(code: 'unavailable');
      final report = controller();
      await report.prepare();
      final bundle = report.snapshot.bundle!;
      adapter.reply(bundle);
      await report.upload();

      expect(report.snapshot.phase, LogReportPhase.failed);
      expect(report.snapshot.bundle, same(bundle));
      expect(adapter.requests, isEmpty);
      expect((await journal.snapshot()).events.single.elapsedMs, 37);

      readMetadata = () async => {
        'packageName': 'com.vvtech.aiassistant.test',
        'versionName': '1.0.52',
        'versionCode': 45,
      };
      await report.upload();
      expect(report.snapshot.phase, LogReportPhase.success);
      expect(report.snapshot.bundle, same(bundle));
      final data = adapter.requests.single.data as FormData;
      expect(
        Map.fromEntries(data.fields)['deviceInfo'],
        contains('Android 14 (API 34)'),
      );
      expect((await journal.snapshot()).events, isEmpty);
    },
  );

  test(
    'account switch while reading metadata cannot send the old ZIP',
    () async {
      final metadata = Completer<Map<String, Object?>>();
      var reads = 0;
      readMetadata = () {
        if (reads++ == 0) throw PlatformException(code: 'unavailable');
        return metadata.future;
      };
      final report = controller();
      await report.prepare();
      adapter.reply(report.snapshot.bundle!);
      final upload = report.upload();
      await Future<void>.delayed(Duration.zero);
      await container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              phone: '13800000000',
              inviteRequired: false,
              accountId: 'synthetic-next-account',
              accessToken: 'synthetic-next-token',
            ),
          );
      metadata.complete({
        'packageName': 'com.vvtech.aiassistant.test',
        'versionName': '1.0.52',
        'versionCode': 45,
      });
      await upload;

      expect(adapter.requests, isEmpty);
      expect((await journal.snapshot()).events.single.elapsedMs, 37);
    },
  );
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async => value = text;
}

class _SessionStore implements SessionStore {
  AuthSession? value = const AuthSession(
    accountId: 'synthetic-account',
    phone: '13800000000',
    accessToken: 'synthetic-token',
  );
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async => value = session;
  @override
  Future<void> clear() async => value = null;
}

class _Adapter implements HttpClientAdapter {
  int status = 200;
  final requests = <RequestOptions>[];
  Map<String, Object?> response = {};
  void reply(AppLogBundle bundle) {
    response = {
      'id': 1,
      'accountId': 'synthetic-account',
      'originalFileName': bundle.fileName,
      'fileSize': bundle.bytes.length,
      'checksumSha256': sha256.convert(bundle.bytes).toString(),
    };
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) await requestStream.drain<void>();
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': response}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
