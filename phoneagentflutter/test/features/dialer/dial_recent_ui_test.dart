import 'package:flutter/material.dart';
import '../../support/dial_permission_overrides.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/translation_model_selection_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_recent_source.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_recent_controller.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_route.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_recent_list.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';

class CountingDialer implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('history select and disabled unknown at $width / 1.3 text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DialRecentCall? selected;
      final snapshot = await const PreviewDialRecentSource(
        DialRecentSource.app,
      ).load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: DialRecentList(
                state: DialRecentState(app: snapshot),
                onSelect: (v) => selected = v,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('dial-recent:app:preview-translation')),
      );
      expect(selected?.restorablePhone, '+12025550103');
      selected = null;
      await tester.tap(
        find.byKey(const ValueKey('dial-recent:app:preview-unknown')),
      );
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('not connected is not successful empty; errors have retry', (
    tester,
  ) async {
    var retries = 0;
    Future<void> show(DialRecentState state) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialRecentList(
            state: state,
            onSelect: (_) {},
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await show(const DialRecentState());
    expect(find.text('暂无通话记录'), findsNothing);
    expect(find.byKey(const Key('dial-history-source-status')), findsOneWidget);
    await show(
      const DialRecentState(
        system: DialRecentSnapshot(DialRecentAccess.unsupported),
        app: DialRecentSnapshot(DialRecentAccess.ready),
      ),
    );
    expect(find.text('暂无通话记录'), findsOneWidget);
    await show(
      const DialRecentState(
        system: DialRecentSnapshot(DialRecentAccess.failed),
        app: DialRecentSnapshot(DialRecentAccess.ready),
      ),
    );
    await tester.tap(find.byKey(const Key('dial-recent-retry')));
    expect(retries, 1);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final translation in [false, true]) {
      for (final restrictPeer in [false, true]) {
        testWidgets(
          'route $platform / $translation history restores peer modelRestricted=$restrictPeer without calling',
          (tester) async {
            final options = translationOptionsFixture();
            final directory = ApiTranslationDirectory.decode({
              ...options,
              'models': [
                for (final model
                    in (options['models'] as List).cast<Map<String, Object?>>())
                  {
                    ...model,
                    'targetLanguageCodes': restrictPeer
                        ? ['en']
                        : ['zh', 'en', 'ja', 'fr'],
                  },
              ],
            });
            final port = CountingDialer();
            final setup = TranslationSetupController()
              ..directory(syntheticTranslationDirectory)
              ..language('ja', caller: false)
              ..enable(false);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  ...grantedDialPermissionOverrides(),
                  selectedTranslationModelProvider.overrideWith(
                    (ref) => directory.model('OPENAI'),
                  ),
                  loginEpochProvider.overrideWithValue(1),
                  systemDialRecentSourceProvider.overrideWithValue(
                    const PreviewDialRecentSource(DialRecentSource.system),
                  ),
                  appDialRecentSourceProvider.overrideWithValue(
                    const PreviewDialRecentSource(DialRecentSource.app),
                  ),
                  dialerControllerProvider.overrideWith(
                    (ref) => DialerController(port),
                  ),
                  translationSetupProvider.overrideWith((ref) => setup),
                  translationDirectoryProvider.overrideWith(
                    (_) async => syntheticTranslationDirectory,
                  ),
                ],
                child: MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: translation
                      ? TranslationDialerRoute(systemDialer: port)
                      : const DialerRoute(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byKey(const Key('dial-call')));
            await tester.tap(find.byKey(const Key('dial-call')));
            await tester.pumpAndSettle();
            expect(find.text('202 555 0101'), findsOneWidget);
            if (translation) {
              expect(setup.snapshot.caller, 'en');
              expect(setup.snapshot.peer, 'en');
              setup.enable(true);
              setup.language('fr', caller: false);
              await tester.pumpAndSettle();
            }
            expect(port.calls, 0);
            await tester.longPress(find.byKey(const Key('dial-delete')));
            await tester.pumpAndSettle();
            final row = find.byKey(
              const ValueKey('dial-recent:app:preview-translation'),
            );
            await tester.ensureVisible(row);
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(find.text('202 555 0103'), findsOneWidget);
            expect(find.text('+1'), findsOneWidget);
            expect(port.calls, 0);
            expect(setup.snapshot.enabled, translation);
            expect(setup.snapshot.caller, 'ja');
            expect(setup.snapshot.peer, 'en');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets('MOCK unified dialer stays isolated and closes directly', (
    tester,
  ) async {
    final realSetup = TranslationSetupController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationSetupProvider.overrideWith((ref) => realSetup),
          dialRecentProvider.overrideWith(
            (ref) => throw StateError('real source must not run'),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openDialer(context, preview: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final row = find.byKey(
      const ValueKey('dial-recent:app:preview-translation'),
    );
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('202 555 0103'), findsOneWidget);
    expect(realSetup.snapshot.country, 'CN');
    expect(realSetup.snapshot.caller, 'zh');
    expect(find.text('MOCK · 配置仅保存在本次演练，不修改正式设置'), findsOneWidget);
    expect(find.text('配置已保存在当前环境，将用于新发起的翻译通话'), findsNothing);
    expect(find.text('MOCK · 拨号交互演练，不会拨出电话'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('dial-close')));
    await tester.tap(find.byKey(const Key('dial-close')));
    await tester.pumpAndSettle();
    expect(find.byType(DialerRoute), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
