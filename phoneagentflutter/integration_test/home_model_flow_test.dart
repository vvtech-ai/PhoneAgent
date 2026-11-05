import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../test/support/shell_fakes.dart';

class _MemorySession implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'synthetic',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('home navigation model switch rollback voice and back', (
    tester,
  ) async {
    final home = FakeHomeRepository(), models = FakeCallModelRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(_MemorySession()),
          homeRepositoryProvider.overrideWithValue(home),
          callModelRepositoryProvider.overrideWithValue(models),
        ],
        child: const PhoneAgentApp(),
      ),
    );
    await tester.pumpUntilUiSettled();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpUntilUiSettled();
    await binding.takeScreenshot('home');
    Future<void> tap(String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    }

    await tap('homeVoiceModelChip');
    await binding.takeScreenshot('models-sheet');
    models.fail = true;
    await tap('model-DOUBAO');
    expect(find.text('切换失败，已保留原模型'), findsOneWidget);
    expect(models.provider, 'QWEN_OMNI_PLUS');
    models.fail = false;
    await tap('model-DOUBAO');
    expect(find.text('通话模型：Seeduplex'), findsOneWidget);
    await tap('tab-1');
    expect(find.text('此模块正在迁移，暂未接入'), findsOneWidget);
    await tap('tab-2');
    await tap('tab-3');
    await tester.tap(find.text('语音模型与音色'));
    await tester.pumpUntilUiSettled();
    await binding.takeScreenshot('models-page');
    await tap('voices-DOUBAO');
    await binding.takeScreenshot('voices-page');
    await tap('voice-v2');
    expect(models.voice, 'v2');
    await tap('backFromVoiceIdentity');
    await tester.binding.handlePopRoute();
    await tester.pumpUntilUiSettled();
    await tap('tab-0');
    expect(home.rotations, 1);
    expect(tester.takeException(), isNull);
    binding.reportData = {
      ...?binding.reportData,
      'routes': [
        'home',
        'model-sheet',
        'models',
        'voices',
        'contacts-pending',
        'tasks-pending',
        'settings',
      ],
      'network': 'offline synthetic only',
      'writes': models.saves,
      'sloganSelections': home.rotations,
    };
  });
}
