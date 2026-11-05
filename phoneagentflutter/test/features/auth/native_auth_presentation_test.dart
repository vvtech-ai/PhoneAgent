import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/data/method_channel_legal_document_port.dart';
import 'package:phone_agent/features/auth/domain/legal_document_port.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_page.dart';

void main() {
  testWidgets('iOS agreement gates SMS, button and keyboard submission', (
    tester,
  ) async {
    var sends = 0;
    var submits = 0;
    final opened = <LegalDocument>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: AuthPage(
          state: const AuthState(phone: '13800000000', code: '1234'),
          actions: AuthActions(
            phone: (_) {},
            code: (_) {},
            invite: (_) {},
            back: () {},
            sendCode: () => sends++,
            submit: () => submits++,
            openDocument: opened.add,
          ),
        ),
      ),
    );
    expect(find.text('PhoneAgent'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('loginGetCode')));
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    await tester.showKeyboard(find.byKey(const ValueKey('loginCode')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sends, 0);
    expect(submits, 0);
    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('userAgreement')));
    await tester.tap(find.byKey(const ValueKey('privacyPolicy')));
    expect(opened, [LegalDocument.userAgreement, LegalDocument.privacyPolicy]);
    expect(sends, 0);
    await tester.tap(find.byKey(const ValueKey('loginAgreement')));
    await tester.pump();
    expect(find.byKey(const ValueKey('loginAgreementError')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('loginGetCode')));
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    expect(sends, 1);
    expect(submits, 1);
  });

  testWidgets('Android agreement gates login and busy Done is blocked', (
    tester,
  ) async {
    var submits = 0;
    Widget page(AuthBusy busy) => MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: AuthPage(
        state: AuthState(phone: '13800000000', code: '1234', busy: busy),
        actions: AuthActions(
          phone: (_) {},
          code: (_) {},
          invite: (_) {},
          back: () {},
          sendCode: () {},
          submit: () => submits++,
        ),
      ),
    );
    await tester.pumpWidget(page(AuthBusy.none));
    expect(find.text('PhoneAgent'), findsOneWidget);
    expect(find.byKey(const ValueKey('loginAgreement')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('loginAgreement')));
    await tester.pump();
    await tester.showKeyboard(find.byKey(const ValueKey('loginCode')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submits, 1);
    await tester.pumpWidget(page(AuthBusy.loggingIn));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submits, 1);
  });

  testWidgets('iOS short screen, keyboard and large type remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: AuthPage(
          state: const AuthState(),
          actions: AuthActions(
            phone: (_) {},
            code: (_) {},
            invite: (_) {},
            back: () {},
            sendCode: () {},
            submit: () {},
            openDocument: (_) {},
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('loginBtn')));
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    await tester.pump();
    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test(
    'legal port passes only document identifier and propagates failure',
    () async {
      const channel = MethodChannel('phone_agent/legal_documents');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.arguments == 'privacyPolicy') {
              throw PlatformException(code: 'UNAVAILABLE');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const port = MethodChannelLegalDocumentPort();
      await port.open(LegalDocument.userAgreement);
      await expectLater(
        port.open(LegalDocument.privacyPolicy),
        throwsA(isA<PlatformException>()),
      );
      expect(calls.map((call) => call.method), ['open', 'open']);
      expect(calls.map((call) => call.arguments), [
        'userAgreement',
        'privacyPolicy',
      ]);
    },
  );
}
