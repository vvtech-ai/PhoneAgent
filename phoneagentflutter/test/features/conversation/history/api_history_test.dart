import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/conversation/data/history/api_conversation_history_repository.dart';
import 'package:phone_agent/features/conversation/data/history/api_timeline_source.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_sync.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/history/timeline_request_failure.dart';

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'token',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {
    credentials = null;
  }
}

class _Adapter implements HttpClientAdapter {
  int timelineStatus = 200;
  bool malformed = false;
  bool legacy = false;
  Map<String, Object?>? timelineError;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async {
    requests.add(r);
    final timeline = r.uri.path.endsWith('/timeline');
    final data = timeline && timelineError != null
        ? timelineError
        : timeline
        ? {
            'sessionId': 's',
            'schemaVersion': 1,
            'ledgerHeadSequence': legacy ? 0 : 1,
            'hasMore': false,
            'projection': {
              'conversationStatus': 'CLOSED',
              'conversationContinuable': false,
              'pendingToolRestorable': false,
              'migrationStatus': 'CURRENT',
              'projectedThroughSequence': legacy ? 0 : 1,
            },
            'events': legacy
                ? []
                : malformed
                ? 'invalid'
                : [
                    {
                      'eventId': 'e1',
                      'sessionId': 's',
                      'sequence': 1,
                      'eventType': 'USER_TURN_ACCEPTED',
                      'schemaVersion': 1,
                      'payload': {'text': 'hello'},
                    },
                  ],
          }
        : {
            'code': 0,
            'data': {
              'sessionId': 's',
              'title': 'Synthetic',
              'status': 'CLOSED',
              'messagesJson': 'DO NOT PARSE',
            },
          };
    return ResponseBody.fromString(
      jsonEncode(data),
      timeline ? timelineStatus : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Session session;
  late _Adapter adapter;
  late AccountApi api;
  late ApiConversationHistoryRepository repo;
  setUp(() {
    session = _Session();
    adapter = _Adapter();
    api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test/'),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    repo = ApiConversationHistoryRepository(
      api,
      LedgerSync(ApiTimelineSource(api)),
      'synthetic',
    );
  });
  test(
    'detail envelope then raw timeline with bearer and numeric query',
    () async {
      final result = await repo.restore('s');
      expect(result.ledger!.events.single.payload['text'], 'hello');
      expect(result.canRestorePending, false);
      expect(result.compatibilityReason, isNull);
      expect(adapter.requests.last.uri.queryParameters['limit'], '100');
      expect(
        adapter.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer token',
        ),
        true,
      );
    },
  );
  test(
    'raw timeline error retains safe retry and migration recovery metadata',
    () async {
      adapter.timelineStatus = 409;
      adapter.timelineError = {
        'errorCode': 'TIMELINE_MIGRATION_INCOMPLETE',
        'retryable': true,
        'recoveryAction': 'WAIT_FOR_MIGRATION',
        'message': 'private body must not appear',
      };
      await expectLater(
        repo.restore('s'),
        throwsA(
          isA<TimelineRequestFailure>()
              .having((e) => e.retryable, 'retryable', true)
              .having((e) => e.recoveryAction, 'recovery', 'WAIT_FOR_MIGRATION')
              .having((e) => e.notice, 'safe notice', '历史正在迁移，请稍后重试'),
        ),
      );
    },
  );
  test(
    '503 remains retryable failure; only explicit empty ledger falls back',
    () async {
      adapter.timelineStatus = 503;
      await expectLater(
        repo.restore('s'),
        throwsA(TimelineFailure.unavailable),
      );
      adapter.timelineStatus = 403;
      await expectLater(repo.restore('s'), throwsA(ApiFailure.rejected));
      adapter.timelineStatus = 200;
      adapter.malformed = true;
      await expectLater(
        repo.restore('s'),
        throwsA(TimelineFailure.invalidResponse),
      );
      adapter.malformed = false;
      adapter.legacy = true;
      final fallback = await repo.restore('s');
      expect(fallback.ledger, isNull);
      expect(fallback.compatibilityReason, TimelineFailure.legacyNoLedger);
    },
  );
  test(
    'repository from old account cannot start requests for new account',
    () async {
      session.credentials = const AccountCredentials(
        'new-account',
        'new-token',
        2,
      );
      await expectLater(repo.restore('s'), throwsA(ApiFailure.sessionChanged));
      expect(adapter.requests, isEmpty);
    },
  );
  for (final status in [500, 502, 504, 599]) {
    test(
      'timeline $status remains retryable without legacy fallback',
      () async {
        adapter.timelineStatus = status;
        adapter.legacy = true;
        await expectLater(
          repo.restore('s'),
          throwsA(TimelineFailure.unavailable),
        );
      },
    );
  }
}
