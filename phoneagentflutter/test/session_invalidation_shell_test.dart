import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import 'support/local_storage_channel_fake.dart';
import 'support/pump_ui_transitions.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'production router removes modal and shows one login expiry on $platform',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        installLocalStorageChannelFake();
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        await tester.tap(find.byKey(const ValueKey('scene-app')));
        await tester.pumpUntilUiSettled();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final session = container.read(sessionControllerProvider.notifier);
        final owner = session.credentials!;
        final navigator = container
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentState!;
        navigator.push<void>(
          DialogRoute(
            context: navigator.context,
            builder: (_) => const AlertDialog(content: Text('失效账号弹窗')),
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(find.text('失效账号弹窗'), findsOneWidget);
        final exit = session.invalidateSession(
          owner,
          SessionInvalidationReason.revoked,
        );
        await tester.pumpUntilUiSettled();
        await exit;
        await tester.pumpUntilUiSettled();
        expect(find.text('失效账号弹窗'), findsNothing);
        expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        expect(find.text('登录状态已失效，请重新登录'), findsOneWidget);
        await session.invalidateSession(
          owner,
          SessionInvalidationReason.revoked,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpUntilUiSettled();
        expect(find.text('登录状态已失效，请重新登录'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
