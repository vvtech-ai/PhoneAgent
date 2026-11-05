import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/translation/data/preview_translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import '../../support/synthetic_account_api.dart';
import '../translation/domestic_provider_repository_test.dart' show catalog;
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/domestic_translation_settings_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_provider_catalog.dart';
import 'package:phone_agent/features/translation/presentation/controller/domestic_translation_settings_controller.dart';
import '../../support/developer_tools_fixture.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform failed model switch shows short legacy notice', (
      tester,
    ) async {
      final repository = _Repository()..selectFails = true;
      await openDeveloperTools(
        tester,
        platform: platform,
        overrides: [
          domesticTranslationSettingsProvider.overrideWith((_) {
            final controller = DomesticTranslationSettingsController(
              repository: repository,
              isCurrent: () => true,
            );
            controller.load();
            return controller;
          }),
        ],
      );
      await tester.tap(find.text('查看 ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设为账号偏好'));
      await tester.pumpAndSettle();
      expect(repository.selected, 'A');
      expect(find.text('同声传译模型切换失败，请检查网络或本地服务连接'), findsOneWidget);
      expect(find.text('翻译通话模型切换失败'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'production settings provider follows simulated region and rejects old controller',
    () async {
      final session = SessionController(_SessionStore());
      await session.restore();
      final setup = TranslationSetupController();
      final location = PreviewTranslationLocation()
        ..cached = TrustedTranslationLocation('CN', 100);
      final server = SyntheticAccountApi()..data = catalog('QWEN_OMNI_PLUS');
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith((_) => session),
          accountApiProvider.overrideWithValue(server.api),
          translationSetupProvider.overrideWith((_) => setup),
          translationLocationStoreProvider.overrideWithValue(location),
          translationLocationSourceProvider.overrideWithValue(location),
        ],
      );
      final subscription = container.listen(
        domesticTranslationSettingsProvider,
        (_, __) {},
      );
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      await settle();
      expect(server.requests.last.uri.queryParameters['region'], 'DOMESTIC');
      final old = container.read(domesticTranslationSettingsProvider.notifier);
      setup.simulateCountry('JP');
      await settle();
      expect(server.requests.last.uri.queryParameters['region'], 'OVERSEAS');
      final count = server.requests.length;
      await old.selectModel('DOUBAO');
      expect(server.requests.length, count);
      server.data = catalog('DOUBAO');
      await container
          .read(domesticTranslationSettingsProvider.notifier)
          .selectModel('DOUBAO');
      expect(server.requests.last.data, {
        'region': 'OVERSEAS',
        'provider': 'DOUBAO',
      });
      expect(setup.snapshot.overseasModelId, '');
      subscription.close();
      container.dispose();
      server.api.close();
    },
  );

  testWidgets(
    'account model refresh/select uses account controller and preserves dial choice',
    (tester) async {
      final repository = _Repository();
      final f = await openDeveloperTools(
        tester,
        overrides: [
          domesticTranslationSettingsProvider.overrideWith((_) {
            final controller = DomesticTranslationSettingsController(
              repository: repository,
              isCurrent: () => true,
            );
            controller.load();
            return controller;
          }),
        ],
      );
      final before = f.container.read(translationSetupProvider).value;
      await tester.tap(find.text('查看 ›'));
      await tester.pumpAndSettle();
      expect(find.text('当前地区：国内'), findsOneWidget);
      expect(find.text('账号模型偏好仅供调试；拨号页选中的模型用于发起通话'), findsOneWidget);
      expect(find.text('模型甲'), findsOneWidget);
      await tester.tap(find.text('设为账号偏好'));
      await tester.pumpAndSettle();
      expect(repository.selected, 'B');
      final after = f.container.read(translationSetupProvider).value;
      expect(after.domesticModelId, before.domesticModelId);
      expect(after.overseasModelId, before.overseasModelId);
      expect(after.provider, before.provider);
      final loads = repository.loads;
      await tester.tap(find.text('刷新状态'));
      await tester.pumpAndSettle();
      expect(repository.loads, loads + 1);
      await tester.tap(find.byTooltip('返回').last);
      await tester.pumpAndSettle();
      expect(find.text('开发者功能'), findsOneWidget);
    },
  );
}

class _Repository implements DomesticProviderRepository {
  bool selectFails = false;
  String selected = 'A';
  int loads = 0;
  DomesticProviderCatalog get catalog => DomesticProviderCatalog(
    activeWireId: selected,
    options: [
      for (final id in ['A', 'B'])
        DomesticProviderOption(
          wireId: id,
          engine: '',
          active: id == selected,
          configured: true,
          available: true,
          statusMessage: '可用',
          name: id == 'A' ? '模型甲' : '模型乙',
        ),
    ],
  );
  @override
  Future<DomesticProviderCatalog> load() async {
    loads++;
    return catalog;
  }

  @override
  Future<DomesticProviderCatalog> select(String wireId) async {
    if (selectFails) throw StateError('synthetic switch failure');
    selected = wireId;
    return catalog;
  }
}

class _SessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}
