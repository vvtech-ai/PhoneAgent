import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/support_feedback_providers.dart';
import 'package:phone_agent/features/support_feedback/presentation/feedback_controller.dart';
import 'package:phone_agent/features/support_feedback/presentation/feedback_page.dart';
import 'package:phone_agent/features/support_feedback/presentation/feedback_route.dart';
import 'feedback_controller_test.dart' show Gateway, Logs;

void main() {
  testWidgets(
    'covered and disposed feedback callbacks cannot edit or submit',
    (tester) async {
      final gateway = Gateway();
      final controller = FeedbackController(
        gateway: gateway,
        logs: Logs(),
        current: () => true,
        deviceInfo: () async => 'device',
      )..edit(description: '问题');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            supportFeedbackProvider.overrideWith((_) => controller),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            home: const FeedbackRoute(),
          ),
        ),
      );
      final page = tester.widget<FeedbackPage>(find.byType(FeedbackPage));
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('cover')),
      );
      await tester.pumpAndSettle();
      page.onDescription('不应生效');
      page.onLogs(true);
      page.onSubmit();
      await tester.pumpAndSettle();
      expect(gateway.requests, isEmpty);
      expect(controller.snapshot.description, '问题');
      expect(controller.snapshot.includeLogs, isFalse);
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      page.onAdd();
      page.onSubmit();
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
