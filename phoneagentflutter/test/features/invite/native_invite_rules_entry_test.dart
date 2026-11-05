import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_rules_sheet.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('rules only current host opens once $platform', (tester) async {
      const activity = InviteActivity(
        id: 'synthetic',
        name: '合成活动',
        rules: '1. 合成规则',
        inviterPoints: 0,
        inviteePoints: 0,
        quota: 8,
      );
      final navigator = GlobalKey<NavigatorState>();
      final observer = _Routes();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showInviteRules(context, activity),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      final old = tester.widget<TextButton>(find.byType(TextButton)).onPressed!;
      final initial = observer.pushes;
      old();
      old();
      await tester.pumpAndSettle();
      expect(observer.pushes, initial + 1);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('活动规则'), findsNothing);
      expect(find.text('打开'), findsOneWidget);
      old();
      await tester.pumpAndSettle();
      expect(observer.pushes, initial + 2);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('新页面'))),
      );
      await tester.pumpAndSettle();
      final background = observer.pushes;
      old();
      await tester.pumpAndSettle();
      expect(observer.pushes, background);
      expect(find.text('新页面'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      navigator.currentState!.pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('替换页面'))),
      );
      await tester.pumpAndSettle();
      final replaced = observer.pushes;
      old();
      await tester.pumpAndSettle();
      expect(observer.pushes, replaced);
      expect(find.text('替换页面'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
