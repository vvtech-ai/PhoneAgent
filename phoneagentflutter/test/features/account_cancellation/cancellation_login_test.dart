import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';

class _Auth implements AuthGateway, CancellationAuthGateway {
  final pending = CancellationPendingLogin(
    'application',
    DateTime.utc(2026, 11, 10),
    'limited-challenge',
  );
  int revoked = 0;
  bool fail = false;
  final operations = <String>[];
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission s) async => LoginOutcome(
    phone: s.phone,
    inviteRequired: false,
    cancellation: pending,
  );
  @override
  Future<LoginOutcome> revokeCancellation(
    CancellationPendingLogin p,
    String id,
    String phone,
  ) async {
    revoked++;
    operations.add(id);
    if (fail) throw AuthFailure.network;
    return LoginOutcome(
      phone: phone,
      inviteRequired: false,
      accountId: 'account',
      accessToken: 'synthetic-token',
    );
  }

  @override
  Future<CancellationResult> lookupCancellation(
    String queryToken,
    String operationId,
  ) async => throw UnimplementedError();
}

void main() {
  test(
    'pending identity is not authenticated; keeping it never calls revoke',
    () async {
      final gateway = _Auth();
      var authenticated = 0;
      final controller = AuthController(
        gateway,
        onAuthenticated: (_) async {
          authenticated++;
        },
      );
      addTearDown(controller.dispose);
      controller.changePhone('13800000000');
      controller.changeCode('123456');
      await controller.submit();
      expect(controller.state.cancellation, isNotNull);
      expect(authenticated, 0);
      await controller.submit();
      expect(gateway.revoked, 0);
      controller.keepCancellation();
      expect(controller.state.cancellation, isNull);
      expect(gateway.revoked, 0);
    },
  );
  test(
    'explicit continue alone authenticates; failed revoke keeps identity and stable operation',
    () async {
      final gateway = _Auth()..fail = true;
      var authenticated = 0;
      final controller = AuthController(
        gateway,
        onAuthenticated: (_) async {
          authenticated++;
        },
      );
      addTearDown(controller.dispose);
      controller.changePhone('13800000000');
      controller.changeCode('123456');
      await controller.submit();
      await controller.continueCancellation();
      expect(authenticated, 0);
      expect(controller.state.cancellation, isNotNull);
      gateway.fail = false;
      await controller.continueCancellation();
      expect(authenticated, 1);
      expect(gateway.operations.toSet(), hasLength(1));
      expect(controller.state.cancellation, isNull);
    },
  );
}
