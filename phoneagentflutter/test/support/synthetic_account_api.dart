import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';

/// Offline protocol fixture. Never sends network traffic or stores credentials.
class SyntheticAccountApi implements AccountSession, HttpClientAdapter {
  SyntheticAccountApi({DiagnosticSink? diagnostics}) {
    api = AccountApi(
      AppConfig.parse(environment: 'dev', apiBaseUrl: 'https://example.test/'),
      this,
      diagnostics: diagnostics,
      client: Dio()..httpClientAdapter = this,
    );
  }
  late final AccountApi api;
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'a',
    'synthetic',
    1,
  );
  int status = 200;
  Object? data = <String, Object?>{};
  final requests = <RequestOptions>[];
  Future<void> Function(RequestOptions)? beforeResponse;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    await beforeResponse?.call(request);
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}
