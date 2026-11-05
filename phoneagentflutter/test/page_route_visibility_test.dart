import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform page ownership follows replace/remove above a popup',
      (tester) async {
        final observer = PageRouteVisibilityObserver();
        final changes = <PageRoute<dynamic>?>[];
        observer.addListener(() => changes.add(observer.currentPage));
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: const Scaffold(body: Text('任务列表')),
          ),
        );
        await tester.pumpAndSettle();
        final taskPage = observer.currentPage;
        expect(taskPage, isNotNull);
        showGeneralDialog<void>(
          context: tester.element(find.text('任务列表')),
          pageBuilder: (_, __, ___) => const Material(child: Text('弹层')),
        );
        await tester.pumpAndSettle();
        expect(observer.currentPage, same(taskPage));
        final detail = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('详情')),
        );
        navigator.currentState!.push(detail);
        await tester.pumpAndSettle();
        expect(observer.currentPage, same(detail));
        final replacement = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('替换详情')),
        );
        navigator.currentState!.replace(
          oldRoute: detail,
          newRoute: replacement,
        );
        await tester.pumpAndSettle();
        expect(observer.currentPage, same(replacement));
        navigator.currentState!.removeRoute(replacement);
        await tester.pumpAndSettle();
        expect(find.text('弹层'), findsOneWidget);
        expect(observer.currentPage, same(taskPage));
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('任务列表'), findsOneWidget);
        expect(changes, [taskPage, detail, replacement, taskPage]);
        await tester.pumpWidget(const SizedBox());
        observer.dispose();
      },
    );
  }
}
