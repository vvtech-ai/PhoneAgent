import '../../support/pump_ui_transitions.dart';
import '../../support/local_storage_channel_fake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/initialization_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/shell_fakes.dart';
import '../../support/conversation_fakes.dart';

class _SuccessfulGateway implements AuthGateway {
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission submission) async => LoginOutcome(
    phone: submission.phone,
    accountId: 'synthetic-account',
    inviteRequired: false,
    accessToken: 'synthetic-token',
  );
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform login and restore reach home and tasks without initialization',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        installLocalStorageChannelFake();
        var initializationStarts = 0;
        Widget app() => ProviderScope(
          overrides: [
            initializationControllerProvider.overrideWith((ref) {
              initializationStarts++;
              throw StateError('initialization must not block the main shell');
            }),
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://example.test',
              ),
            ),
            authGatewayProvider.overrideWithValue(_SuccessfulGateway()),
            homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
            taskRepositoryProvider.overrideWithValue(OfflineTasks()),
            callModelRepositoryProvider.overrideWithValue(
              FakeCallModelRepository(),
            ),
          ],
          child: const PhoneAgentApp(),
        );
        await tester.pumpWidget(app());
        await tester.pumpUntilUiSettled();
        await tester.enterText(
          find.byKey(const ValueKey('loginPhone')),
          '13800000000',
        );
        await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
        await tester.tap(find.byKey(const ValueKey('loginAgreement')));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('loginBtn')));
        await tester.pumpUntilUiSettled();
        expect(
          find.byKey(const ValueKey('homeVoiceModelChip')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('loginCode')), findsNothing);
        Future<void> checkTabs() async {
          await tester.tap(find.byKey(const ValueKey('tab-2')));
          await tester.pumpUntilUiSettled();
          expect(
            find.byKey(const ValueKey('conversation:closed')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('tab-0')));
          await tester.pumpUntilUiSettled();
          expect(
            find.byKey(const ValueKey('homeVoiceModelChip')),
            findsOneWidget,
          );
          expect(find.text('初始化设置'), findsNothing);
          expect(initializationStarts, 0);
          expect(tester.takeException(), isNull);
        }

        await checkTabs();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpUntilUiSettled();
        await tester.pumpWidget(app());
        await tester.pumpUntilUiSettled();
        expect(
          find.byKey(const ValueKey('homeVoiceModelChip')),
          findsOneWidget,
        );
        await checkTabs();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpUntilUiSettled();
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
