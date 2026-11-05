import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';

class TestGateway implements AuthGateway {
  final submissions = <LoginSubmission>[];
  int sends = 0;
  int cooldown = 60;
  Object? sendError;
  Future<LoginOutcome> Function()? respond;
  @override
  Future<CodeDelivery> sendCode(String phone) async {
    sends++;
    if (sendError != null) throw sendError!;
    return CodeDelivery(phone, cooldown);
  }

  @override
  Future<LoginOutcome> login(LoginSubmission submission) async {
    submissions.add(submission);
    return respond != null
        ? respond!()
        : const LoginOutcome(
            phone: '13800000000',
            inviteRequired: true,
            loginChallenge: 'synthetic',
          );
  }
}

void main() {
  late TestGateway gateway;
  late AuthController controller;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 9, 16);
    gateway = TestGateway();
    controller = AuthController(gateway, now: () => now);
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });

  test(
    'changing normalized phone clears SMS and challenge but same number does not',
    () async {
      controller.changePhone('13800000000');
      controller.changeCode('123456');
      controller.changePhone('+86 １３８００００００００');
      expect(controller.state.code, '123456');
      controller.changePhone('13900000000');
      expect(controller.state.code, isEmpty);
      controller.changeCode('123456');
      await controller.submit();
      expect(controller.state.challenge, isNotEmpty);
      controller.changePhone('13900000000');
      expect(controller.state.challenge, isEmpty);
    },
  );
  test(
    'SMS sending accepts code but blocks phone edits and duplicate sends',
    () async {
      controller.changePhone('13800000000');
      final sending = controller.sendCode();
      expect(controller.state.busy, AuthBusy.sendingCode);
      controller.changeCode('123456');
      controller.changePhone('13900000000');
      final duplicate = controller.sendCode();
      final login = controller.submit();
      expect(controller.state.code, '123456');
      expect(controller.state.phone, '13800000000');
      expect(gateway.sends, 1);
      expect(gateway.submissions, isEmpty);
      await Future.wait([sending, duplicate, login]);
      expect(controller.state.code, '123456');
    },
  );
  test('v65 phone prefix and full-width paste sanitization', () {
    expect(sanitizeLoginPhone('+86 １３８-００００-００００'), '13800000000');
    expect(sanitizeLoginPhone('008613800000000'), '13800000000');
    expect(sanitizeLoginPhone('12', '1'), '1');
    expect(sanitizeLoginPhone('2'), '');
  });
  test('persistence retry never resubmits an already consumed SMS', () async {
    controller.dispose();
    var attempts = 0;
    controller = AuthController(
      gateway,
      onAuthenticated: (_) async {
        attempts++;
        if (attempts == 1) throw AuthFailure.storage;
      },
    );
    gateway.respond = () async => const LoginOutcome(
      phone: '13800000000',
      accountId: 'synthetic',
      inviteRequired: false,
      accessToken: 'synthetic',
    );
    controller.changePhone('13800000000');
    controller.changeCode('123456');
    await controller.submit();
    expect(controller.state.outcome, isNull);
    expect(controller.state.notice, contains('重试保存'));
    expect(controller.state.code, isEmpty);
    await controller.submit();
    expect(attempts, 2);
    expect(gateway.submissions.length, 1);
    expect(controller.state.outcome, isNotNull);
  });
  test('only four to eight digit SMS accepted', () {
    for (final value in [
      '1234',
      '12345',
      '123456',
      '1234567',
      '12345678',
      ' 1234 ',
      ' 12345678 ',
    ]) {
      expect(isSmsCode(value), isTrue, reason: value);
    }
    for (final value in [
      '',
      '123',
      '123456789',
      'abcdef',
      '12 3456',
      '１２３４',
      '12a4',
    ]) {
      expect(isSmsCode(value), isFalse, reason: value);
    }
  });
  for (final code in ['1234', '12345', '123456', '1234567', '12345678']) {
    test('$code is submitted unchanged to the login gateway', () async {
      controller.changePhone('13800000000');
      controller.changeCode(code);
      await controller.submit();
      expect(gateway.submissions, hasLength(1));
      expect(gateway.submissions.single.code, code);
    });
  }
  for (final code in ['123', '123456789', '12a4']) {
    test('$code is rejected before login gateway invocation', () async {
      controller.changePhone('13800000000');
      controller.changeCode(code);
      await controller.submit();
      expect(gateway.submissions, isEmpty);
      expect(controller.state.notice, '请输入正确的验证码');
    });
  }
  test('invalid input never reaches gateway', () async {
    await controller.sendCode();
    await controller.submit();
    controller.changePhone('13800000000');
    controller.changeCode('123');
    await controller.submit();
    expect(gateway.sends, 0);
    expect(gateway.submissions, isEmpty);
    expect(controller.state.notice, '请输入正确的验证码');
  });
  test(
    'cooldown scoped to canonical phone and based on elapsed time',
    () async {
      controller.changePhone('13800000000');
      await controller.sendCode();
      await controller.sendCode();
      expect(gateway.sends, 1);
      controller.changePhone('13900000000');
      expect(controller.state.visibleRetrySeconds, 0);
      controller.changePhone('13800000000');
      expect(controller.state.visibleRetrySeconds, 60);
      now = now.add(const Duration(seconds: 61));
      controller.refreshCooldown();
      expect(controller.state.visibleRetrySeconds, 0);
      await controller.sendCode();
      expect(gateway.sends, 2);
    },
  );
  test('server cooldown has minimum one second', () async {
    gateway.cooldown = 0;
    controller.changePhone('13800000000');
    await controller.sendCode();
    expect(controller.state.retrySeconds, 1);
  });
  test(
    'invitation reuses challenge and omits old SMS; back requires SMS',
    () async {
      controller.changePhone('13800000000');
      controller.changeCode('123456');
      await controller.submit();
      expect(controller.state.invitation, isTrue);
      expect(controller.state.code, isEmpty);
      await controller.submit();
      expect(gateway.submissions.length, 1);
      controller.changeInvite(' invite ');
      await controller.submit();
      expect(gateway.submissions.last.loginChallenge, 'synthetic');
      expect(gateway.submissions.last.code, '');
      expect(gateway.submissions.last.activationCode, 'invite');
      controller.backToLogin();
      await controller.submit();
      expect(gateway.submissions.length, 2);
      controller.changeCode('123456');
      await controller.submit();
      expect(gateway.submissions.last.loginChallenge, isNull);
    },
  );
  test('invitation without challenge preserves SMS', () async {
    gateway.respond = () async =>
        const LoginOutcome(phone: '13800000000', inviteRequired: true);
    controller.changePhone('13800000000');
    controller.changeCode('123456');
    await controller.submit();
    controller.changeInvite('invite');
    await controller.submit();
    expect(gateway.submissions.last.code, '123456');
  });
  test('busy invite blocks back and duplicate submit', () async {
    controller.changePhone('13800000000');
    controller.changeCode('123456');
    await controller.submit();
    controller.changeInvite('invite');
    final pending = Completer<LoginOutcome>();
    gateway.respond = () => pending.future;
    final request = controller.submit();
    await controller.submit();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.submissions.length, 2);
    controller.backToLogin();
    expect(controller.state.invitation, isTrue);
    pending.complete(
      const LoginOutcome(phone: '13800000000', inviteRequired: false),
    );
    await request;
    expect(controller.state.invitation, isFalse);
    expect(controller.state.outcome, isNotNull);
    expect(controller.state.working, isFalse);
  });
  test('disposal safely ignores late success', () async {
    final pending = Completer<LoginOutcome>();
    gateway.respond = () => pending.future;
    controller.changePhone('13800000000');
    controller.changeCode('123456');
    final request = controller.submit();
    controller.dispose();
    pending.complete(
      const LoginOutcome(phone: '13800000000', inviteRequired: true),
    );
    await request;
  });
  test('error is safe, busy cleared, retry remains possible', () async {
    gateway.respond = () async => throw StateError('登录暂不可用');
    controller.changePhone('13800000000');
    controller.changeCode('123456');
    await controller.submit();
    expect(controller.state.notice, '登录失败，请稍后重试');
    expect(controller.state.working, isFalse);
    gateway.respond = () async => const LoginOutcome(
      phone: '13800000000',
      inviteRequired: false,
      accessToken: 'synthetic',
    );
    await controller.submit();
    expect(controller.state.outcome?.accessToken, 'synthetic');
    expect(controller.state.code, isEmpty);
  });
  for (final sendingCode in [true, false]) {
    final operation = sendingCode ? 'send code' : 'SMS login';
    test(
      '$operation preserves classified failures and hides unknown messages',
      () async {
        final fallback = sendingCode ? '获取验证失败，请稍后重试' : '登录失败，请稍后重试';
        for (final entry in <Object, String>{
          AuthFailure.offline: '当前无网络连接，请检查网络设置',
          AuthFailure.timeout: '网络连接超时，请检查网络设置',
          AuthFailure.network: '暂时无法连接登录服务，请稍后重试',
          AuthFailure.unavailable: '登录服务尚未接入，请稍后再试',
          AuthFailure.rejected: '验证失败，请检查输入后重试',
          AuthFailure.incorrectCode: '验证码不正确',
          AuthFailure.codeExpired: '验证码已过期或失效，请重新获取',
          AuthFailure.challengeExpired: '登录验证已过期，请返回登录重新获取验证码',
          AuthFailure.invalidInvite: '邀请码无效或已失效，请检查后重试',
          AuthFailure.rateLimited: '操作太频繁，请稍后重试',
          AuthFailure.invalidResponse: '登录服务响应异常，请稍后重试',
          const AuthMessageFailure(''): fallback,
          const AuthMessageFailure('   '): fallback,
          const AuthMessageFailure('服务维护中'): fallback,
          StateError('服务内部错误'): fallback,
          Exception(''): fallback,
          Object(): fallback,
          AuthFailure.storage: fallback,
        }.entries) {
          gateway.sendError = entry.key;
          gateway.respond = () async => throw entry.key;
          controller.changePhone('13800000000');
          controller.changeCode('123456');
          if (sendingCode) {
            await controller.sendCode();
          } else {
            await controller.submit();
          }
          expect(
            controller.state.notice,
            entry.value,
            reason: '$operation: ${entry.key}',
          );
          expect(controller.state.working, isFalse);
          expect(controller.state.visibleRetrySeconds, 0);
          expect(controller.state.outcome, isNull);
        }
        gateway.sendError = null;
        gateway.respond = () async => const LoginOutcome(
          phone: '13800000000',
          inviteRequired: false,
          accessToken: 'synthetic',
        );
        if (sendingCode) {
          await controller.sendCode();
          expect(controller.state.notice, '验证码已发送');
          expect(controller.state.visibleRetrySeconds, 60);
        } else {
          await controller.submit();
          expect(controller.state.outcome?.accessToken, 'synthetic');
        }
      },
    );
  }
}
