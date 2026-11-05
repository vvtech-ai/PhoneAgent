import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/support_feedback/data/api_feedback_gateway.dart';
import 'package:phone_agent/features/support_feedback/domain/feedback.dart';

void main() {
  late _Adapter adapter;
  late _Session session;
  late AccountApi api;
  setUp(() {
    adapter = _Adapter();
    session = _Session();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/agent',
        sdkApiBaseUrl: 'https://example.test/sdk',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
  });
  tearDown(() => api.close());
  for (final logs in [false, true]) {
    test(
      'multipart preserves image order, original text and log choice $logs',
      () async {
        final request = FeedbackRequest(
          description: '第一行\n第二行',
          contact: ' 001 微信 ',
          deviceInfo: 'Flutter android / 1.0(2)',
          images: [
            for (var i = 0; i < 6; i++)
              FeedbackImage(
                Uint8List.fromList([i]),
                'image$i.png',
                'image/png',
              ),
          ],
          logs: logs
              ? AppLogBundle(
                  watermark: 3,
                  count: 1,
                  bytes: Uint8List.fromList([7]),
                  fileName: 'log.zip',
                )
              : null,
        );
        adapter.receipt = {
          'id': '9007199254740993',
          'feedbackNo': 'FK001',
          'requestId': request.requestId,
          'submittedAt': '2026-10-26T16:00:00+08:00',
          'imageCount': 6,
          'hasLogs': logs,
        };
        await ApiFeedbackGateway(api).submit(request);
        final sent = adapter.requests.single;
        expect(sent.uri.toString(), 'https://example.test/sdk/api/feedback');
        expect(sent.headers['Authorization'], 'Bearer synthetic-token');
        final form = sent.data as FormData;
        expect(Map.fromEntries(form.fields), {
          'requestId': request.requestId,
          'description': '第一行\n第二行',
          'contact': ' 001 微信 ',
          'includeLogs': '$logs',
          'deviceInfo': 'Flutter android / 1.0(2)',
        });
        expect(form.files.map((f) => f.key), [
          'image0',
          'image1',
          'image2',
          'image3',
          'image4',
          'image5',
          if (logs) 'log',
        ]);
        for (var i = 0; i < 6; i++) {
          expect(
            await form.files[i].value
                .clone()
                .finalize()
                .expand((b) => b)
                .toList(),
            [i],
          );
        }
      },
    );
  }
  test('incomplete attachment receipt is not accepted as success', () async {
    final request = FeedbackRequest(
      description: '问题',
      contact: '',
      images: [],
      logs: null,
      deviceInfo: '',
    );
    adapter.receipt = {
      'id': '1',
      'feedbackNo': 'FK1',
      'requestId': request.requestId,
      'submittedAt': '2026-10-26T16:00:00+08:00',
      'imageCount': 1,
      'hasLogs': false,
    };
    await expectLater(
      ApiFeedbackGateway(api).submit(request),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test('changed account cannot send the previous feedback', () async {
    session.credentialsValue = const AccountCredentials(
      'other',
      'other-token',
      2,
    );
    await expectLater(
      ApiFeedbackGateway(api).submit(
        FeedbackRequest(
          description: '问题',
          contact: '',
          images: [],
          logs: null,
          deviceInfo: '',
        ),
      ),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(adapter.requests, isEmpty);
  });
}

class _Session implements AccountSession {
  AccountCredentials? credentialsValue = const AccountCredentials(
    'owner',
    'synthetic-token',
    1,
  );
  @override
  AccountCredentials? get credentials => credentialsValue;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, Object> receipt = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await stream?.drain<void>();
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': receipt}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
