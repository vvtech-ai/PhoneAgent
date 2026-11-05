import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'package:phone_agent/features/settings/presentation/widgets/logout_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    Future<GlobalKey<NavigatorState>> open(
      WidgetTester tester,
      Future<void> Function() signOut,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showLogoutConfirmation(context, signOut),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return navigator;
    }

    VoidCallback action(WidgetTester tester, String label) => tester
        .widget<NativeGradientAction>(
          find.byWidgetPredicate(
            (w) => w is NativeGradientAction && w.label == label,
          ),
        )
        .onPressed!;

    testWidgets('$platform late covered failure can retry on return', (
      tester,
    ) async {
      var calls = 0;
      final pending = Completer<void>();
      final navigator = await open(tester, () {
        calls++;
        return calls == 1 ? pending.future : Future<void>.value();
      });
      action(tester, '退出')();
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        ),
      );
      await tester.pumpAndSettle();
      pending.completeError(StateError('synthetic failure'));
      await tester.pumpAndSettle();
      expect(find.text('cover'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('退出失败，请重试'), findsOneWidget);
      action(tester, '退出')();
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform covered and disposed old logout actions', (
      tester,
    ) async {
      var calls = 0;
      final navigator = await open(tester, () async {
        calls++;
      });
      final cancel = action(tester, '取消');
      final confirm = action(tester, '退出');
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        ),
      );
      await tester.pumpAndSettle();
      cancel();
      confirm();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('cover'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      cancel();
      confirm();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(tester.takeException(), isNull);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('$platform busy old cancel and late success keep cover', (
      tester,
    ) async {
      var calls = 0;
      final pending = Completer<void>();
      final navigator = await open(tester, () {
        calls++;
        return pending.future;
      });
      final cancel = action(tester, '取消');
      final confirm = action(tester, '退出');
      confirm();
      confirm();
      cancel();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('退出中…'), findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        ),
      );
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('cover'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
