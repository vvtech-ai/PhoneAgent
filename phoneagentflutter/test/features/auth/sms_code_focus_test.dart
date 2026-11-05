import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_page.dart';

void main() {
  testWidgets('covered route does not steal focus on send', (tester) async {
    final busy = ValueNotifier<AuthBusy>(AuthBusy.none);
    addTearDown(busy.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder<AuthBusy>(
          valueListenable: busy,
          builder: (_, value, __) => AuthPage(
            state: AuthState(busy: value),
            actions: AuthActions(
              phone: (_) {},
              code: (_) {},
              invite: (_) {},
              sendCode: () {},
              submit: () {},
              back: () {},
            ),
          ),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('其他页面')),
      ),
    );
    await tester.pumpAndSettle();
    busy.value = AuthBusy.sendingCode;
    await tester.pump();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('其他页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('send transition focuses once and accepts code $platform', (
      tester,
    ) async {
      String code = '';
      Future<void> render(AuthBusy busy) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: AuthPage(
            state: AuthState(phone: '13800000000', busy: busy),
            actions: AuthActions(
              phone: (_) {},
              code: (v) => code = v,
              invite: (_) {},
              sendCode: () {},
              submit: () {},
              back: () {},
            ),
          ),
        ),
      );
      await render(AuthBusy.none);
      expect(tester.testTextInput.isVisible, isFalse);
      await render(AuthBusy.sendingCode);
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('loginCode')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('loginPhone')))
            .enabled,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const ValueKey('loginCode')),
        'a12-3456789',
      );
      expect(code, '12345678');
      expect(field.controller!.text, '12345678');
      await tester.enterText(find.byKey(const ValueKey('loginCode')), '1234');
      expect(code, '1234');
      field.focusNode!.unfocus();
      await tester.pump();
      await render(AuthBusy.sendingCode);
      await tester.pump();
      expect(field.focusNode!.hasFocus, isFalse);
      await render(AuthBusy.none);
      await tester.pump();
      expect(field.focusNode!.hasFocus, isFalse);
      await render(AuthBusy.sendingCode);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
