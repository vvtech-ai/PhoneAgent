import '../../invite/domain/invite.dart';
import '../../invite/data/api_invite_repository.dart' show inviteErrorCodes;
import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/account_session.dart';
import '../../../core/network/service_routes.dart';
import '../../../core/network/signing/c1_transport.dart';
import '../../../core/diagnostics/diagnostic_auth_details.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_session.dart';
import 'auth_request_diagnostics.dart';
import 'auth_network_status.dart'
    if (dart.library.io) 'auth_network_status_io.dart';

class DioAuthGateway implements AuthGateway {
  DioAuthGateway(
    AppConfig config, {
    Dio? client,
    DiagnosticSink? Function()? diagnostics,
    this.signing,
    Future<bool> Function()? isOffline,
  }) : _client = client ?? Dio(),
       _diagnostics = diagnostics,
       _isOffline = isOffline ?? isAuthNetworkOffline,
       _baseUri = config.isConfigured
           ? config.sdkApiBaseUri ?? config.apiBaseUri
           : null {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 20),
      followRedirects: false,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }
  final Dio _client;
  final Future<bool> Function() _isOffline;
  final Uri? _baseUri;
  final C1Transport? signing;
  final DiagnosticSink? Function()? _diagnostics;

  void close() => _client.close(force: true);

  @override
  Future<CodeDelivery> sendCode(String phone) {
    final request = AuthRequestDiagnostics(
      DiagnosticOperation.authSendCode,
      _diagnostics,
    );
    return request.run(
      () => _sendCode(phone, request),
      (_) => DiagnosticAuthOutcome.codeAccepted,
    );
  }

  Future<CodeDelivery> _sendCode(
    String phone,
    AuthRequestDiagnostics request,
  ) async {
    final data = await _post('send-code', {'phone': phone}, request);
    final resultPhone = _text(data, 'phone');
    if (resultPhone != phone || !isLoginPhone(resultPhone)) {
      throw AuthFailure.invalidResponse;
    }
    return CodeDelivery(
      resultPhone,
      _integer(data, 'resendCooldownSeconds'),
      expireSeconds: _integer(data, 'expireSeconds'),
      eventId: _text(data, 'eventId'),
    );
  }

  @override
  Future<LoginOutcome> login(LoginSubmission submission) {
    final request = AuthRequestDiagnostics(
      DiagnosticOperation.authLogin,
      _diagnostics,
    );
    return request.run(
      () => _login(submission, request),
      (result) => result.inviteRequired
          ? DiagnosticAuthOutcome.inviteRequired
          : DiagnosticAuthOutcome.credentialsReturned,
    );
  }

  Future<LoginOutcome> _login(
    LoginSubmission submission,
    AuthRequestDiagnostics request,
  ) async {
    final data = await _post('login', {
      'phone': submission.phone,
      if (submission.registrationRequestId != null)
        'registrationRequestId': submission.registrationRequestId,
      if (submission.invitationSource != null)
        'invitationSource': submission.invitationSource,
      'code': submission.code,
      if (submission.activationCode?.trim().isNotEmpty ?? false)
        'activationCode': submission.activationCode!.trim(),
      if (submission.loginChallenge?.trim().isNotEmpty ?? false)
        'loginChallenge': submission.loginChallenge!.trim(),
    }, request);
    final phone = _text(data, 'phone');
    if (phone != submission.phone || !isLoginPhone(phone)) {
      throw AuthFailure.invalidResponse;
    }
    final invite = data['inviteRequired'] ?? false;
    if (invite is! bool) throw AuthFailure.invalidResponse;
    final grants = data['grantEvents'] ?? [];
    if (grants is! List) throw AuthFailure.invalidResponse;
    final referral = data['referralResult'] is Map<String, dynamic>
        ? data['referralResult'] as Map<String, dynamic>
        : <String, dynamic>{};
    final result = LoginOutcome(
      referralOperationId: referral['operationId'] is String
          ? referral['operationId']
          : '',
      referralPoints: referral['inviteePoints'] is int
          ? referral['inviteePoints']
          : null,
      phone: phone,
      inviteRequired: invite,
      loginChallenge: _optionalText(data, 'loginChallenge'),
      accountId: _optionalText(data, 'accountId'),
      accessToken: _optionalText(data, 'voiceCloneAccessToken'),
      displayName: _optionalText(data, 'displayName'),
      points: data['points'] == null ? null : _points(_object(data['points'])),
      grantEvents: List.unmodifiable(
        grants.map((e) {
          final item = _object(e);
          return AuthGrantEvent(
            type: _text(item, 'type'),
            amount: _integer(item, 'amount'),
            businessDate: _text(item, 'businessDate'),
          );
        }),
      ),
    );
    if (!invite && !result.toSession().valid) throw AuthFailure.invalidResponse;
    return result;
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, Object?> body,
    AuthRequestDiagnostics request,
  ) async {
    final base = _baseUri;
    if (base == null) throw AuthFailure.unavailable;
    final normalized = base.replace(
      path: base.path.endsWith('/') ? base.path : '${base.path}/',
    );
    final url = normalized.resolve('api/auth/sms/$endpoint');
    try {
      final signed = await signing?.prepare(
        url,
        service: ApiService.sdk,
        method: 'POST',
        token: '',
        body: body,
      );
      final response = await _client.postUri<Object?>(
        url,
        data: signed?.$1 ?? body,
        options: Options(headers: signed?.$2),
      );
      request.statusCode = response.statusCode ?? 0;
      return _unwrap(response.data);
    } on ApiFailure {
      throw AuthFailure.unavailable;
    } on DioException catch (error) {
      request.statusCode = error.response?.statusCode ?? 0;
      if (error.response == null &&
          const {
            DioExceptionType.connectionTimeout,
            DioExceptionType.sendTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.connectionError,
          }.contains(error.type) &&
          await _confirmedOffline()) {
        throw AuthFailure.offline;
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw AuthFailure.timeout;
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          throw AuthFailure.network;
        default:
          break;
      }
      if (error.response?.data is Map) {
        final envelope = _object(error.response!.data);
        _inviteFailure(envelope);
        throw _failure(envelope['message']);
      }
      throw AuthMessageFailure(error.message ?? '');
    }
  }

  Future<bool> _confirmedOffline() async {
    try {
      return await _isOffline()
          .then<bool>(
            (offline) => offline,
            onError: (Object _, StackTrace __) => false,
          )
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _unwrap(Object? value) {
    final root = _object(value);
    if (root['code'] is! num && root['code'] is! String) {
      throw AuthFailure.invalidResponse;
    }
    if (root['code'] is String &&
        !RegExp(
          r'^(000000|[A-Z]{2}[0-9]{4})$',
        ).hasMatch(root['code'] as String)) {
      throw AuthFailure.invalidResponse;
    }
    if (root['code'] != 0 && root['code'] != '000000') {
      _inviteFailure(root);
      throw _failure(root['message']);
    }
    return _object(root['data']);
  }

  static void _inviteFailure(Map<String, dynamic> root) {
    final data = root['data'];
    final code = data is Map ? data['errorCode'] : null;
    if (code is String && inviteErrorCodes.contains(code)) {
      throw InviteFailure(code);
    }
  }

  // Preserve known business categories; carry only the message for other errors.
  static Object _failure(Object? message) {
    final text = message is String ? message : '';
    if (text.contains('验证码已过期') || text.contains('错误次数过多')) {
      return AuthFailure.codeExpired;
    }
    if (text.contains('验证码不正确')) return AuthFailure.incorrectCode;
    if (text.contains('频繁')) return AuthFailure.rateLimited;
    if (text.contains('邀请码')) return AuthFailure.invalidInvite;
    if (text.contains('重新登录') || text.contains('挑战')) {
      return AuthFailure.challengeExpired;
    }
    return AuthMessageFailure(text);
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw AuthFailure.invalidResponse;
    return value;
  }

  static String _text(Map<String, dynamic> data, String key) {
    final result = _optionalText(data, key);
    if (result.isEmpty) throw AuthFailure.invalidResponse;
    return result;
  }

  static String _optionalText(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    if (value is! String) throw AuthFailure.invalidResponse;
    return value.trim();
  }

  static int _integer(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! int) throw AuthFailure.invalidResponse;
    return value;
  }

  static AuthPoints _points(Map<String, dynamic> data) => AuthPoints(
    availableBalance: _integer(data, 'availableBalance'),
    heldBalance: _integer(data, 'heldBalance'),
    totalBalance: _integer(data, 'totalBalance'),
    updatedAt: _text(data, 'updatedAt'),
  );
}
