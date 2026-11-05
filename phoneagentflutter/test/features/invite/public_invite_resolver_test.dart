import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/invite/data/api_invite_repository.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import '../../support/synthetic_account_api.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_welcome_controller.dart';

class _PublicResponse implements HttpClientAdapter {
  _PublicResponse(this.code, this.status);
  final Object? code;
  final String status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'code': code,
      'data': {
        'code': 'ABCD',
        'status': status,
        if (status == 'ACTIVE') 'activity': {'inviteePoints': 20},
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

PublicInviteResolver responseResolver(Object? code, String status) {
  final resolver = PublicInviteResolver(
    AppConfig.parse(
      environment: 'dev',
      apiBaseUrl: 'https://example.test/',
      sdkApiBaseUrl: 'https://sdk.test/',
    ),
    client: Dio()..httpClientAdapter = _PublicResponse(code, status),
  );
  addTearDown(resolver.close);
  return resolver;
}

void main() {
  test(
    'iOS string success with retired status displays ended activity and no reward',
    () async {
      final controller = InviteWelcomeController(
        responseResolver('000000', 'ACTIVITY_RETIRED'),
        'ABCD',
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.error, '本期邀请活动已结束，无法使用此邀请码完成注册。已有账号请返回登录。');
      expect(controller.state.points, isNull);
      expect(controller.state.canContinue, true);
    },
  );
  for (final code in [0, '000000']) {
    test('success $code loads ACTIVE rewards', () async {
      expect(await responseResolver(code, 'ACTIVE').resolve('ABCD'), 20);
    });
    for (final status in ['ACTIVITY_RETIRED', 'EXPIRED', 'EXHAUSTED']) {
      test(
        'success $code preserves business status $status without activity',
        () async {
          await expectLater(
            responseResolver(code, status).resolve('ABCD'),
            throwsA(
              isA<InviteFailure>().having(
                (e) => e.code,
                'code',
                'INVITE_$status',
              ),
            ),
          );
        },
      );
    }
  }
  for (final code in ['0', '000001', null]) {
    test('non-success $code is never coerced into success', () async {
      await expectLater(
        responseResolver(code, 'ACTIVE').resolve('ABCD'),
        throwsA(
          isA<InviteFailure>().having((e) => e.code, 'code', 'UNAVAILABLE'),
        ),
      );
    });
  }
  for (final sdk in [true, false]) {
    test('public resolve SDK configured=$sdk uses no credentials', () async {
      final backend = SyntheticAccountApi()
        ..data = {
          'code': 'ABCD',
          'status': 'ACTIVE',
          'activity': {'inviteePoints': 20},
        };
      final resolver = PublicInviteResolver(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://agent.test/aiassistant-api/',
          sdkApiBaseUrl: sdk ? 'https://sdk.test/aiassistant-sdk-api/' : null,
        ),
        client: Dio()..httpClientAdapter = backend,
      );
      addTearDown(resolver.close);
      expect(await resolver.resolve('ABCD'), 20);
      final request = backend.requests.single;
      expect(request.uri.host, sdk ? 'sdk.test' : 'agent.test');
      expect(
        request.uri.path,
        sdk
            ? '/aiassistant-sdk-api/api/invite/public/resolve'
            : '/aiassistant-api/api/invite/public/resolve',
      );
      expect(request.uri.queryParameters, {'code': 'ABCD'});
      expect(
        request.headers.keys.any((key) => key.toLowerCase() == 'authorization'),
        false,
      );
    });
  }
  test('mismatched response cannot display another invite reward', () async {
    final backend = SyntheticAccountApi()
      ..data = {
        'code': 'EFGH',
        'status': 'ACTIVE',
        'activity': {'inviteePoints': 20},
      };
    final resolver = PublicInviteResolver(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://agent.test/',
        sdkApiBaseUrl: 'https://sdk.test/',
      ),
      client: Dio()..httpClientAdapter = backend,
    );
    addTearDown(resolver.close);
    await expectLater(resolver.resolve('ABCD'), throwsA(isA<InviteFailure>()));
  });
}
