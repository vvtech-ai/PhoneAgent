import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

const ocrTestSession = 'synthetic-session';
const ocrTestId = 'ocr-synthetic';
final ocrTestBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
Map<String, Object?> ocrPayload({
  String id = ocrTestId,
  int anchor = 2,
  int ordinal = 3,
}) => {
  'attachmentId': id,
  'sessionId': ocrTestSession,
  'contentPath':
      '/api/agent/conversations/$ocrTestSession/attachments/$id/content',
  'contentType': 'image/png',
  'fileSize': ocrTestBytes.length,
  'anchorStepCount': anchor,
  'createdOrdinal': ordinal,
  'fields': [
    {'label': '内容', 'value': '合成图片文字'},
  ],
  'segments': ['合成图片文字'],
  'fullText': '合成图片文字',
  'eventId': 'synthetic-event',
  'sequence': 9,
  'committedAt': '2026-09-17T08:00:00Z',
};
OcrUpload ocrUpload({
  Uint8List? bytes,
  String sessionId = ocrTestSession,
  String? skillId,
  SelectedContactContext? contact,
}) => OcrUpload(
  sessionId: sessionId,
  attachment: const OcrAttachment(
    id: ocrTestId,
    imageRef: 'local-image',
    anchor: 2,
    ordinal: 3,
  ),
  bytes: bytes ?? ocrTestBytes,
  fileName: 'C:\\private\\synthetic.png',
  mimeType: 'image/png',
  initialOpening: '合成开场',
  initialSkillId: skillId,
  selectedContact: contact,
  recognition: const OcrRecognition('合成图片文字', ['合成图片文字']),
);

class OcrTestSession implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic-account',
    'old',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) async {
    if (expected.sameLogin(credentials)) credentials = null;
  }
}

class OcrTestAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <Uint8List>[];
  late FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = BytesBuilder();
    if (stream != null) {
      await for (final chunk in stream) {
        bytes.add(chunk);
      }
    }
    bodies.add(bytes.takeBytes());
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

AccountApi ocrTestApi(OcrTestSession session, OcrTestAdapter adapter) =>
    AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/prefix/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
ResponseBody ocrJson(Object? data, {int status = 200, String? error}) =>
    ResponseBody.fromString(
      jsonEncode({
        'code': error == null
            ? 0
            : status == 200
            ? 500
            : status,
        if (error != null) 'message': error,
        'data': data,
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
ResponseBody ocrBinary({
  Stream<Uint8List>? stream,
  int status = 200,
  String type = 'image/png',
  int? length,
}) => ResponseBody(
  stream ?? Stream.value(ocrTestBytes),
  status,
  headers: {
    Headers.contentTypeHeader: [type],
    if (length != null) Headers.contentLengthHeader: ['$length'],
  },
);
