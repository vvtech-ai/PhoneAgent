import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/translation_archive_providers.dart';
import 'package:phone_agent/app/translation_finished_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'package:phone_agent/features/translation/domain/translation_call_finished.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';
import '../../support/translation_session_fixture.dart';
import 'translation_finished_recorder_test.dart' show CountingRecords;

class _Wallet implements PointsWalletRepository {
  int reads = 0;
  @override
  Future<PointsAccount> account() async {
    reads++;
    return const PointsAccount(
      totalBalance: 900,
      availableBalance: 800,
      heldBalance: 100,
      updatedAt: 'synthetic',
    );
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      PointsLedgerPage(
        items: const [],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final recordFails in [false, true]) {
    test(
      'formal terminal refresh deduplicates and isolates account; recordFails=$recordFails',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final records = CountingRecords()..fail = recordFails;
        final wallet = _Wallet();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://synthetic.invalid/',
              ),
            ),
            appCallRecordRepositoryProvider.overrideWithValue(records),
            pointsWalletRepositoryProvider.overrideWithValue(wallet),
            pointsWalletCacheProvider.overrideWithValue(
              const EmptyPointsWalletCache(),
            ),
            translationArchiveProvider.overrideWith(
              (ref) => TranslationArchiveController(
                accountId: 'owner',
                store: null,
                gateway: null,
                isCurrent: () => false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final session = container.read(sessionControllerProvider.notifier);
        Future<void> login(String account) => session.accept(
          LoginOutcome(
            phone: '13800000000',
            accountId: account,
            accessToken: 'synthetic',
            inviteRequired: false,
          ),
        );
        await login('owner');
        final factory = container.read(translationSessionFactoryProvider);
        final points = container.read(pointsWalletControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero); // Finish initial cache/GET.
        await points.refresh();
        final before = wallet.reads;
        final fixture = SessionFixture();
        final call = factory.create(
          backend: fixture.backend,
          mediaFactory: (_) => fixture.live,
          loadLanguages: () async => const TranslationServiceCatalog([]),
          request: const TranslationCreateRequest(
            phone: '+12025550101',
            userLanguage: 'zh',
            merchantLanguage: 'en',
            provider: 'GEMINI',
            userId: 'owner',
          ),
          context: const TranslationCallContext(clientCallId: 'terminal-1'),
          targetName: '合成',
          countryIso: 'US',
        );
        addTearDown(call.dispose);
        await call.start();
        await Future<void>.delayed(Duration.zero);
        await factory.recorder.idle;
        expect(wallet.reads, before + 1);
        expect(points.state.account!.availableBalance, 800);
        expect(
          fixture.events,
          isEmpty,
        ); // No call/billing operation on preflight failure.
        call.onFinished!(call.finished!);
        await Future<void>.delayed(Duration.zero);
        expect(wallet.reads, before + 1);
        await login('other');
        await Future<void>.delayed(Duration.zero);
        final afterSwitch = wallet.reads;
        call.onFinished!(call.finished!);
        await Future<void>.delayed(Duration.zero);
        expect(wallet.reads, afterSwitch);
      },
    );
  }
}
