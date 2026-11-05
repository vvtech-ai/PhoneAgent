import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_agent_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/conversation/data/stream/dio_agent_gateway.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

const _sessionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _traceId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _secret = 'PRIVATE-body-phone-token-https://secret.test/';
const _command = AgentCommand(
  sessionId: _sessionId,
  userId: 'synthetic',
  commandId: 'command',
  idempotencyKey: 'intent',
  traceId: _traceId,
  message: _secret,
);

String _frame(String event, Map<String, Object?> data) =>
    'event: $event\ndata: ${jsonEncode(data)}\n\n';
String _done() => _frame('done', {});

void main() {
  late _Session session;
  late _Adapter adapter;
  late _Store store;
  late DiagnosticJournal journal;
  late DioAgentGateway gateway;
  final events = <DiagnosticEvent>[];
  var sinkFails = false;
  setUp(() {
    events.clear();
    sinkFails = false;
    session = _Session();
    adapter = _Adapter();
    store = _Store();
    journal = DiagnosticJournal(
      store,
      flushDelay: const Duration(days: 1),
      minimumLevel: DiagnosticLogLevel.debug,
    );
    gateway = DioAgentGateway(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
      diagnostics: (event) {
        if (sinkFails) throw StateError(_secret);
        events.add(event);
        journal.record(event);
      },
    );
  });
  tearDown(() {
    gateway.close();
    journal.close();
  });

  test(
    'v65 tools, signals and ledger reach recreated journal and actual ZIP',
    () async {
      const tools = [
        'search',
        'stageReport',
        'activateSkill',
        'fillUserIdentity',
        'reportCallOutcome',
        'provideSkillTemplate',
        'generateBatchReceiptCsv',
        'askUser',
        'showOptions',
        'requestPermission',
        'importDocument',
        'confirmBatchTask',
        'makeCall',
        'makeBatchCalls',
        'lookupContact',
        'lookupDeviceContactsByNames',
      ];
      const signals = {
        'TEXT_REPLY': 'textReply',
        'ASK_USER': 'askUser',
        'SHOW_OPTIONS': 'showOptions',
        'REQUEST_PERMISSION': 'requestPermission',
        'IMPORT_DOCUMENT_REQUEST': 'importDocument',
        'MAKE_CALL_REQUEST': 'makeCall',
        'LOOKUP_CONTACT_REQUEST': 'lookupContact',
        'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST':
            'lookupDeviceContactsByNames',
        'CALL_RESULT': 'callResult',
        'BATCH_CALL_RESULT': 'batchCallResult',
        'ERROR': 'error',
      };
      const ledger = {
        'USER_TURN_ACCEPTED': 'userTurnAccepted',
        'ASSISTANT_TURN_COMMITTED': 'assistantTurnCommitted',
        'TOOL_REQUESTED': 'toolRequested',
        'TOOL_RESULT_RECORDED': 'toolResultRecorded',
        'CALL_REQUESTED': 'callRequested',
        'CALL_STARTED': 'callStarted',
        'CALL_COMPLETED': 'callCompleted',
        'CALL_FAILED': 'callFailed',
        'CALL_CANCELLED': 'callCancelled',
        'CALL_REJECTED': 'callRejected',
        'CALL_OUTCOME_REPORTED': 'callOutcomeReported',
        'CONVERSATION_INTERRUPTED': 'conversationInterrupted',
        'CONVERSATION_RESUMED': 'conversationResumed',
        'OCR_IMAGE_COMMITTED': 'ocrImageCommitted',
        'RUN_FAILED': 'runFailed',
        'RUN_CANCELLED': 'runCancelled',
      };
      var sequence = 0;
      adapter.text = [
        for (final tool in tools) ...[
          for (final phase in ['tool_call_start', 'tool_call_complete'])
            _frame(phase, {
              'sessionId': _sessionId,
              'toolName': tool,
              'toolCallId': _secret,
              'arguments': _secret,
              'result': _secret,
            }),
          _frame('tool_card', {
            'sessionId': _sessionId,
            'data': {
              'toolName': tool,
              'result': _secret,
              'methodLabel': _secret,
            },
          }),
        ],
        for (final signal in signals.keys)
          _frame('signal', {
            'sessionId': _sessionId,
            'type': signal,
            'text': _secret,
          }),
        for (final type in ledger.keys)
          _frame('timeline_committed', {
            'data': {
              'eventId': 'event-${++sequence}',
              'sessionId': _sessionId,
              'sequence': sequence,
              'schemaVersion': 1,
              'eventType': type,
              'payload': {'toolName': 'makeCall', _secret: _secret},
            },
          }),
        _frame('final', {
          'sessionId': _sessionId,
          'type': 'TEXT_REPLY',
          'text': _secret,
        }),
        _done(),
      ].join();
      final output = await gateway.start(_command).events.toList();
      expect(
        output.where((e) => e.kind == AgentEventKind.finalResponse).single.text,
        _secret,
      );
      expect(
        events
            .where((e) => e.agent?.frame == DiagnosticAgentFrame.toolStart)
            .map((e) => e.agent!.tool!.name),
        tools,
      );
      expect(
        events
            .where((e) => e.agent?.frame == DiagnosticAgentFrame.toolComplete)
            .map((e) => e.agent!.tool!.name),
        tools,
      );
      expect(
        events
            .where((e) => e.agent?.frame == DiagnosticAgentFrame.toolCard)
            .map((e) => e.agent!.tool!.name),
        tools,
      );
      expect(
        events
            .where((e) => e.agent?.frame == DiagnosticAgentFrame.signal)
            .map((e) => e.agent!.signal!.name),
        signals.values,
      );
      final committed = events.where(
        (e) => e.agent?.frame == DiagnosticAgentFrame.committed,
      );
      expect(committed.map((e) => e.agent!.ledger!.name), ledger.values);
      expect(
        committed.map((e) => e.agent!.sequence),
        List.generate(16, (i) => i + 1),
      );
      expect(
        events
            .where((e) => e.agent != null)
            .where((e) => e.agent?.signal != DiagnosticAgentSignal.error)
            .every((e) => e.result == DiagnosticResult.received),
        isTrue,
      );
      expect(
        events
            .singleWhere((e) => e.agent?.signal == DiagnosticAgentSignal.error)
            .result,
        DiagnosticResult.failed,
      );
      expect(
        events.every((e) => e.sessionId == _sessionId && e.traceId == _traceId),
        isTrue,
      );
      await journal.flush();
      expect(store.value, isNot(contains(_secret)));
      final restored = DiagnosticJournal(store);
      addTearDown(restored.close);
      final repo = ZipLogRepository(
        restored,
        uploadBundle: (_) async => fail('No upload'),
      );
      final bundle = await repo.prepare();
      final text = utf8.decode(
        ZipDecoder()
                .decodeBytes(bundle.bytes, verify: true)
                .files
                .single
                .content
            as List<int>,
      );
      final json = text.split('\n').map(jsonDecode).toList();
      expect(json, events.map((e) => e.toJson()).toList());
      expect(text, isNot(contains(_secret)));
      expect(adapter.requests, 1);
    },
  );

  test(
    'normalized aliases, unknown types, status and error remain structural',
    () async {
      const aliases = {
        'ask_user': 'askUser',
        'options_available': 'showOptions',
        'request_permission': 'requestPermission',
        'import_document_request': 'importDocument',
        'call_ready': 'makeCall',
        'lookup_contact_request': 'lookupContact',
        'agent_lookup_contact': 'lookupContact',
        'agent_lookup_device_contacts_by_names': 'lookupDeviceContactsByNames',
      };
      adapter.text = [
        for (final name in aliases.keys)
          _frame(name, {
            'sessionId': _sessionId,
            'displayMessage': _secret,
            'data': {},
          }),
        _frame('tool_call_start', {'toolName': _secret}),
        _frame('signal', {'type': _secret, 'text': _secret}),
        _frame('call_status_changed', {
          'data': {'status': _secret},
        }),
        _frame(_secret, {'text': _secret}),
        _frame('error', {'message': _secret}),
        _done(),
      ].join();
      await gateway.start(_command).events.toList();
      expect(
        events
            .where((e) => e.agent?.signal != null)
            .map((e) => e.agent!.signal!.name),
        [...aliases.values, 'unknown'],
      );
      expect(
        events.singleWhere((e) => e.agent?.tool != null).agent!.tool,
        DiagnosticAgentTool.unknown,
      );
      expect(
        events.any((e) => e.agent?.frame == DiagnosticAgentFrame.status),
        isTrue,
      );
      expect(
        events.any((e) => e.agent?.frame == DiagnosticAgentFrame.unknown),
        isTrue,
      );
      expect(
        events
            .singleWhere((e) => e.agent?.frame == DiagnosticAgentFrame.error)
            .result,
        DiagnosticResult.failed,
      );
      expect(events.last.result, DiagnosticResult.failed);
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains(_secret)),
      );
    },
  );

  test('execution error receipts remain in ERROR-level diagnostics', () async {
    adapter.text = [
      _frame('final', {
        'sessionId': _sessionId,
        'type': 'CALL_RESULT',
        'callResult': {'status': 'EXECUTION_ERROR', 'detail': _secret},
      }),
      _frame('signal', {
        'sessionId': _sessionId,
        'type': 'BATCH_CALL_RESULT',
        'batchCallResult': {
          'executionStatus': 'EXECUTION_ERROR',
          'detail': _secret,
        },
      }),
      _done(),
    ].join();
    await gateway.start(_command).events.toList();
    final errorJournal = DiagnosticJournal(
      _Store(),
      minimumLevel: DiagnosticLogLevel.error,
    );
    addTearDown(errorJournal.close);
    for (final event in events) {
      errorJournal.record(event);
    }
    final retained = (await errorJournal.snapshot()).events;
    expect(retained.map((event) => event.agent?.signal), [
      DiagnosticAgentSignal.callResult,
      DiagnosticAgentSignal.batchCallResult,
    ]);
    expect(
      retained.every((event) => event.result == DiagnosticResult.failed),
      isTrue,
    );
    expect(
      jsonEncode(retained.map((event) => event.toJson()).toList()),
      isNot(contains(_secret)),
    );
  });

  test(
    'foreign session is rejected before any event receipt or debug print',
    () async {
      adapter.text = _frame('signal', {
        'sessionId': 'foreign',
        'type': 'ASK_USER',
      });
      final printed = <String>[];
      await runZoned(
        () async {
          await expectLater(
            gateway.start(_command).events.toList(),
            throwsA(AgentTransportFailure.malformed),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printed.add(line),
        ),
      );
      expect(events.where((e) => e.agent != null), isEmpty);
      expect(events.last.result, DiagnosticResult.failed);
      expect(printed, isEmpty);
    },
  );

  test('cancelled live stream does not record late receipt', () async {
    final source = StreamController<Uint8List>();
    adapter.source = source.stream;
    final run = gateway.start(_command);
    final output = run.events.toList();
    await adapter.requested.future;
    run.cancel();
    source.add(
      Uint8List.fromList(utf8.encode(_frame('signal', {'type': 'ASK_USER'}))),
    );
    await source.close();
    expect(await output, isEmpty);
    expect(events.where((e) => e.agent != null), isEmpty);
    expect(events.last.result, DiagnosticResult.cancelled);
  });

  test('old account stream does not record late receipt', () async {
    final source = StreamController<Uint8List>();
    adapter.source = source.stream;
    final result = expectLater(
      gateway.start(_command).events.toList(),
      throwsA(AgentTransportFailure.sessionChanged),
    );
    await adapter.requested.future;
    session.credentials = const AccountCredentials('other', 'unused', 2);
    source.add(
      Uint8List.fromList(utf8.encode(_frame('signal', {'type': 'ASK_USER'}))),
    );
    await source.close();
    await result;
    expect(events.where((e) => e.agent != null), isEmpty);
  });

  test(
    'diagnostic sink failure does not alter tool, signal or completion',
    () async {
      sinkFails = true;
      adapter.text =
          _frame('tool_call_start', {'toolName': 'askUser'}) +
          _frame('signal', {'type': 'ASK_USER', 'text': _secret}) +
          _done();
      final output = await gateway.start(_command).events.toList();
      expect(output.map((e) => e.kind), [
        AgentEventKind.toolStart,
        AgentEventKind.signal,
        AgentEventKind.done,
      ]);
      expect(output[1].text, _secret);
      expect(adapter.requests, 1);
    },
  );

  test(
    'token deltas, heartbeat and done do not fill diagnostic journal',
    () async {
      adapter.text = [
        for (var i = 0; i < 300; i++) ...[
          _frame('text_delta', {'text': _secret}),
          _frame('thinking_delta', {'text': _secret}),
          _frame('heartbeat', {}),
        ],
        _frame('thinking_done', {}),
        _done(),
      ].join();
      await gateway.start(_command).events.toList();
      expect(events.length, 2);
      expect(
        events.map((e) => e.operation),
        everyElement(DiagnosticOperation.agentStream),
      );
    },
  );

  test(
    'old events read unchanged; unknown nested values never roundtrip raw',
    () {
      final old = DiagnosticEvent(
        operation: DiagnosticOperation.agentStream,
        result: DiagnosticResult.started,
      ).toJson();
      expect(DiagnosticEvent.fromJson(old).toJson(), old);
      for (final invalid in [-1, 0, 9007199254740992, _secret, null]) {
        final value = DiagnosticEvent.fromJson({
          ...old,
          'agent': {
            'frame': _secret,
            'signal': _secret,
            'tool': _secret,
            'ledger': _secret,
            'sequence': invalid,
            _secret: _secret,
          },
        }).toJson();
        expect(value['agent'], {
          'frame': 'unknown',
          'signal': 'unknown',
          'tool': 'unknown',
          'ledger': 'unknown',
        });
        expect(jsonEncode(value), isNot(contains(_secret)));
      }
    },
  );
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    _secret,
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  String text = '';
  int requests = 0;
  final requested = Completer<void>();
  Stream<Uint8List>? source;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests++;
    if (!requested.isCompleted) requested.complete();
    return ResponseBody(
      source ?? Stream.value(Uint8List.fromList(utf8.encode(text))),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
