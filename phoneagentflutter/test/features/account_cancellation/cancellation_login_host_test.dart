import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_login_host.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';

class _Gateway implements AuthGateway, CancellationAuthGateway {
  int revokes = 0;
  bool fail = false;
  Completer<void>? gate;
  DateTime effectiveAt = DateTime.utc(2026, 11, 10);
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission s) async => LoginOutcome(
    phone: s.phone,
    inviteRequired: false,
    cancellation: CancellationPendingLogin(
      'application',
      effectiveAt,
      'limited',
    ),
  );
  @override
  Future<LoginOutcome> revokeCancellation(
    CancellationPendingLogin p,
    String id,
    String phone,
  ) async {
    revokes++;
    await gate?.future;
    if (fail) throw AuthFailure.network;
    return LoginOutcome(
      phone: phone,
      inviteRequired: false,
      accountId: 'synthetic',
      accessToken: 'synthetic-token',
    );
  }

  @override
  Future<CancellationResult> lookupCancellation(String q, String id) async =>
      throw UnimplementedError();
}

Future<AuthController> _mount(
  WidgetTester tester,
  _Gateway gateway, {
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
  VoidCallback? onAuthenticated,
}) async {
  final controller = AuthController(
    gateway,
    onAuthenticated: (_) async {
      onAuthenticated?.call();
    },
  );
  controller.changePhone('13800000000');
  controller.changeCode('123456');
  await controller.submit();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith((_) => controller)],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const CancellationLoginHost(child: Scaffold(body: Text('原登录页'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

BoxDecoration _background(WidgetTester tester, String label) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.widgetWithText(NativeGradientAction, label),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final close in ['保持注销', '返回', '继续登录']) {
      testWidgets(
        '$platform $close preserves exact copy, deadline and original choice boundary',
        (tester) async {
          final gateway = _Gateway();
          final expectedTime = platform == TargetPlatform.android
              ? '2026年11月10日 08:00（北京时间）'
              : '2027年01月02日 01:37（北京时间）';
          if (platform == TargetPlatform.iOS) {
            gateway.effectiveAt = DateTime.utc(2027, 1, 1, 17, 37);
          }
          var accepted = 0;
          final controller = await _mount(
            tester,
            gateway,
            platform: platform,
            onAuthenticated: () => accepted++,
          );
          expect(find.text('账号正在注销中'), findsOneWidget);
          expect(
            find.text('你已提交账号注销，将于 $expectedTime 正式注销。若继续登录，注销流程将自动终止。'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<NativeBusinessDialog>(find.byType(NativeBusinessDialog))
                .title,
            '账号正在注销中',
          );
          if (close == '返回') {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.text(close));
          }
          await tester.pumpAndSettle();
          expect(find.text('账号正在注销中'), findsNothing);
          expect(find.text('原登录页'), findsOneWidget);
          expect(gateway.revokes, close == '继续登录' ? 1 : 0);
          expect(accepted, close == '继续登录' ? 1 : 0);
          expect(controller.state.cancellation, isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
    for (final colors in [
      ('保持注销', const Color(0xFFF2F4F7), const Color(0xFFE14D46)),
      ('继续登录', const Color(0xFF111111), Colors.white),
    ]) {
      testWidgets('$platform ${colors.$1} renders required solid colors', (
        tester,
      ) async {
        await _mount(tester, _Gateway(), platform: platform);
        final background = _background(tester, colors.$1);
        expect(background.color, colors.$2);
        expect(background.gradient, isNull);
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, colors.$1),
        );
        expect(button.style!.foregroundColor!.resolve({}), colors.$3);
        expect(button.onPressed, isNotNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets(
      '$platform small 2x dialog keeps original equal actions reachable',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 480);
        addTearDown(tester.view.reset);
        await _mount(tester, _Gateway(), platform: platform, scale: 2);
        final keep = find.widgetWithText(TextButton, '保持注销');
        final proceed = find.widgetWithText(TextButton, '继续登录');
        await tester.ensureVisible(proceed);
        await tester.pumpAndSettle();
        expect(tester.getSize(keep), tester.getSize(proceed));
        expect(tester.getRect(proceed).bottom, lessThanOrEqualTo(480));
        expect(
          tester.getRect(keep).left,
          lessThan(tester.getRect(proceed).left),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(keep);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'pending revoke disables actions; failure retains application and returns chosen palette',
    (tester) async {
      final gateway = _Gateway()
        ..gate = Completer<void>()
        ..fail = true;
      var accepted = 0;
      final controller = await _mount(
        tester,
        gateway,
        onAuthenticated: () => accepted++,
      );
      final original = controller.state.cancellation!;
      final originalConfirm = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '继续登录'))
          .onPressed!;
      await tester.tap(find.text('继续登录'));
      await tester.pump();
      expect(gateway.revokes, 1);
      for (final label in ['保持注销', '处理中…']) {
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(button.onPressed, isNull);
        expect(
          button.style!.foregroundColor!.resolve({WidgetState.disabled}),
          const Color(0xFF9CA7B5),
        );
        expect(
          (_background(tester, label).gradient! as LinearGradient).colors,
          const [Color(0xFFEEF2F7), Color(0xFFE8EDF5)],
        );
      }
      originalConfirm();
      await tester.pump();
      expect(gateway.revokes, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('账号正在注销中'), findsOneWidget);
      gateway.gate!.complete();
      await tester.pumpAndSettle();
      expect(accepted, 0);
      expect(
        controller.state.cancellation?.applicationId,
        original.applicationId,
      );
      expect(controller.state.cancellation?.effectiveAt, original.effectiveAt);
      expect(controller.state.notice, isNotEmpty);
      expect(find.text(controller.state.notice), findsOneWidget);
      expect(_background(tester, '继续登录').color, const Color(0xFF111111));
      await tester.tap(find.text('保持注销'));
      await tester.pumpAndSettle();
      expect(gateway.revokes, 1);
      expect(accepted, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
