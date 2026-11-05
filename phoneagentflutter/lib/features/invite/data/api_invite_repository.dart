import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/invite.dart';
import '../domain/invite_link_policy.dart';
import 'invite_codec.dart';
import 'invite_protocol_diagnostics.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import 'invite_resolve_diagnostics.dart';

const inviteErrorCodes = {
  'INVITER_ACCOUNT_CANCELLED',
  'ACTIVITY_DISABLED',
  'ACTIVITY_UNAVAILABLE',
  'ACTIVITY_RETIRED',
  'INVITE_ACTIVITY_RETIRED',
  'CONFIG_SYNCING',
  'CONFIG_SYNC_PENDING',
  'INVALID_CODE',
  'INVITE_INVALID',
  'INVITE_CODE_FORMAT_INVALID',
  'INVITE_NOT_FOUND',
  'EXPIRED',
  'INVITE_EXPIRED',
  'EXHAUSTED',
  'QUOTA_EXHAUSTED',
  'INVITE_EXHAUSTED',
  'REPLACED',
  'INVITE_REPLACED',
  'INVITE_ACTIVITY_CHANGED',
  'REGISTRATION_RETRYABLE',
  'REGISTRATION_ABORTED',
  'REGISTRATION_NOT_NEW',
  'REQUEST_CONFLICT',
  'CONFIG_NOT_PUBLISHED',
  'EXTERNAL_INVITE_UNAVAILABLE',
  'LOGIN_CHALLENGE_EXPIRED',
  'CHALLENGE_EXPIRED',
  'INVALID_LOGIN_CHALLENGE',
};

class ApiInviteRepository implements InviteRepository {
  ApiInviteRepository(this.api, this.policy);
  final AccountApi api;
  final InviteLinkPolicy policy;
  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, Object?>? query,
  }) async {
    try {
      return inviteObject(
        await api.request(
          'api/invite/$path',
          method: method,
          body: body,
          query: query,
          exposedDataCodes: inviteErrorCodes,
        ),
      );
    } on ApiCodeFailure catch (e) {
      inviteProtocolApiFailure(path, e.code);
      throw InviteFailure(e.code);
    }
  }

  @override
  Future<InviteOverview> activity() async =>
      inviteOverview(await _request('activity'));
  @override
  Future<InviteCode> code() async => inviteCode(
    await _request('me/code', method: 'POST', body: <String, String>{}),
    policy,
  );
  @override
  Future<InviteRecords> records([String? cursor]) async {
    final data = await _request(
      'me/records',
      query: {'size': 20, if (cursor != null) 'cursor': cursor},
    );
    final items = data['items'];
    if (items is! List) throw const InviteFailure('INVALID_RESPONSE');
    final next = inviteText(data, 'nextCursor', optional: true);
    return InviteRecords(
      List.unmodifiable(
        items.map((v) {
          final m = inviteObject(v);
          final inviter = inviteInt(m, 'inviterPoints');
          final bonus = inviteInt(m, 'fullBonusPoints');
          return InviteRecord(
            inviteText(m, 'id'),
            inviteText(m, 'inviteePhone', optional: true),
            inviteText(m, 'registeredAt'),
            inviter + bonus,
            credited:
                (inviter == 0 || m['inviterLedgerId'] != null) &&
                (bonus == 0 || m['fullBonusLedgerId'] != null),
          );
        }),
      ),
      inviteInt(data, 'total'),
      next.isEmpty ? null : next,
    );
  }

  @override
  Future<void> event(String period, String type, String eventId) async {
    if (!{'COPY_CODE', 'COPY_LINK', 'SAVE_POSTER'}.contains(type)) {
      throw const InviteFailure('INVALID_EVENT');
    }
    await _request(
      'me/events',
      method: 'POST',
      body: {'periodId': period, 'type': type, 'eventId': eventId},
    );
  }
}

class PublicInviteResolver implements InviteResolver {
  PublicInviteResolver(
    AppConfig config, {
    Dio? client,
    DiagnosticSink? Function()? diagnostics,
  }) : _base = config.sdkApiBaseUri ?? config.apiBaseUri,
       _diagnostics = diagnostics,
       _client =
           client ??
           Dio(
             BaseOptions(
               followRedirects: false,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               validateStatus: (_) => true,
             ),
           );
  final Uri? _base;
  final DiagnosticSink? Function()? _diagnostics;
  final Dio _client;
  void close() => _client.close(force: true);
  @override
  Future<int> resolve(String code) async {
    final observation = InviteResolveDiagnostics(_diagnostics);
    var status = 0;
    Object? apiCode;
    try {
      if (!InviteLinkPolicy.validCode(code)) {
        throw const InviteFailure('INVALID_CODE');
      }
      final base = _base;
      if (base == null) throw const InviteFailure('CONFIG_UNAVAILABLE');
      final uri = base
          .replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/')
          .resolve('api/invite/public/resolve')
          .replace(queryParameters: {'code': code});
      final response = await _client.getUri<Object?>(uri);
      status = response.statusCode ?? 0;
      final raw = response.data;
      apiCode = raw is Map<String, dynamic> ? raw['code'] : null;
      if (status != 200) throw _responseFailure(raw);
      final root = inviteObject(raw);
      if (apiCode != 0 && apiCode != '000000') throw _responseFailure(root);
      final data = inviteObject(root['data']);
      if (inviteText(data, 'code').toLowerCase() != code.toLowerCase()) {
        throw const InviteFailure('INVITE_INVALID');
      }
      if (data['status'] != 'ACTIVE') {
        final error = 'INVITE_${data['status']}';
        throw InviteFailure(
          inviteErrorCodes.contains(error) ? error : 'INVALID_RESPONSE',
        );
      }
      final activity = data['activity'];
      if (activity is! Map<String, dynamic>) {
        throw const InviteFailure('CONFIG_NOT_PUBLISHED');
      }
      final points = inviteInt(activity, 'inviteePoints');
      observation.finish(null, status: status, apiCode: apiCode);
      return points;
    } on DioException catch (e) {
      final response = e.response;
      final error = e.type == DioExceptionType.badResponse
          ? _responseFailure(response?.data)
          : InviteFailure(
              e.error is FormatException ? 'INVALID_RESPONSE' : 'NETWORK',
            );
      final raw = response?.data;
      observation.finish(
        error.code,
        status: response?.statusCode ?? status,
        apiCode: raw is Map<String, dynamic> ? raw['code'] : apiCode,
      );
      throw error;
    } on InviteFailure catch (e) {
      observation.finish(e.code, status: status, apiCode: apiCode);
      rethrow;
    } catch (_) {
      observation.finish('INVALID_RESPONSE', status: status, apiCode: apiCode);
      throw const InviteFailure('INVALID_RESPONSE');
    }
  }

  InviteFailure _responseFailure(Object? raw) {
    final data = raw is Map<String, dynamic> ? raw['data'] : null;
    final error = data is Map<String, dynamic> ? data['errorCode'] : null;
    return InviteFailure(
      inviteErrorCodes.contains(error) ? error as String : 'UNAVAILABLE',
    );
  }
}
