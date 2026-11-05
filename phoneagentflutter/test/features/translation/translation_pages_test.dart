import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'dart:async';
import 'package:phone_agent/core/widgets/route_provider_scope.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_settings_route.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
import '../../support/dial_permission_overrides.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/developer_network_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/developer_network_mode.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';

class RecordingDialer implements SystemDialer {
  final calls = <String>[];
  @override
  Future<SystemDialResult> open(String number) async {
    calls.add(number);
    return SystemDialResult.opened;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    RecordingDialer dialer, {
    String? number = '+12025550123',
    DeveloperNetworkMode network = DeveloperNetworkMode.normal,
    TranslationDialSessionBinding? binding,
    TranslationAccess access = const TranslationAccess(
      countryIso: 'US',
      forced: false,
    ),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationDirectoryProvider.overrideWith(
            (ref) async => syntheticTranslationDirectory,
          ),
          ...grantedDialPermissionOverrides(),
          networkAvailabilitySourceProvider.overrideWithValue(
            const UnknownNetworkAvailability(),
          ),
          developerNetworkModeProvider.overrideWith((_) => network),
          translationAccessProvider.overrideWithValue(access),
          systemDialRecentSourceProvider.overrideWithValue(
            const UnavailableDialRecentSource(DialRecentAccess.unsupported),
          ),
          translationSetupProvider.overrideWith(
            (ref) => TranslationSetupController(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TranslationDialerRoute(
                      number: number,
                      systemDialer: dialer,
                      sessionBinding: binding,
                    ),
                  ),
                ),
                child: const Text('进入翻译'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入翻译'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'leaving during async preparation disposes late controller without start',
    (tester) async {
      final gate = Completer<TranslationSessionController>();
      final fixture = PreviewTranslationSession();
      final dialer = RecordingDialer();
      var prepares = 0, released = 0;
      await open(
        tester,
        dialer,
        binding: TranslationDialSessionBinding(
          create: (_) {
            prepares++;
            return gate.future;
          },
        ),
      );
      await press(tester, find.byKey(const Key('dial-call')));
      await press(tester, find.widgetWithText(FilledButton, '实时翻译呼叫'));
      await press(tester, find.byKey(const Key('dial-call')));
      expect(prepares, 1);
      await press(tester, find.byKey(const Key('dial-close')));
      final controller = TranslationSessionController(
        backend: fixture,
        mediaFactory: fixture.media,
        loadLanguages: fixture.languages,
        request: PreviewTranslationSession.request,
        onReleased: () => released++,
      );
      gate.complete(controller);
      await tester.pumpAndSettle();
      expect(controller.mounted, isFalse);
      expect(released, 1);
      expect(fixture.creates, 0);
      expect(dialer.calls, isEmpty);
      expect(find.text('进入翻译'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      '$width presets language return cancel and translation blocked',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final dialer = RecordingDialer();
        await open(tester, dialer);
        await press(tester, find.byKey(const Key('dial-call')));
        expect(find.text('实时翻译通话'), findsOneWidget);
        await press(tester, find.byKey(const Key('translation-peer')).last);
        expect(find.text('对方语言'), findsOneWidget);
        await press(tester, find.byKey(const Key('language-fr')));
        expect(find.text('实时翻译通话'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('translation-peer')),
            matching: find.text('法语'),
          ),
          findsOneWidget,
        );
        await press(tester, find.byKey(const Key('translation-presets-close')));
        expect(find.text('202 555 0123'), findsOneWidget);
        await press(tester, find.byKey(const Key('dial-call')));
        await press(tester, find.widgetWithText(FilledButton, '实时翻译呼叫'));
        await tester.ensureVisible(
          find.text('当前环境无法发起实时翻译通话，请在已登录的手机 App 中使用'),
        );
        expect(find.text('当前环境无法发起实时翻译通话，请在已登录的手机 App 中使用'), findsOneWidget);
        expect(dialer.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'language system back returns sheet then dialer; no unrequested call',
    (tester) async {
      final dialer = RecordingDialer();
      await open(tester, dialer);
      await press(tester, find.byKey(const Key('dial-call')));
      await press(tester, find.byKey(const Key('translation-caller')).last);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('实时翻译通话'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('实时翻译通话'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('进入翻译'), findsOneWidget);
      expect(dialer.calls, isEmpty);
    },
  );
  testWidgets('ordinary mode disables languages and uses only explicit call', (
    tester,
  ) async {
    final dialer = RecordingDialer();
    await open(tester, dialer, network: DeveloperNetworkMode.offline);
    await press(tester, find.byKey(const Key('translation-presets-open')));
    await press(tester, find.byKey(const Key('translation-enabled')));
    final language = tester.widget<OutlinedButton>(
      find.byKey(const Key('translation-caller')),
    );
    expect(language.onPressed, isNull);
    await press(tester, find.byKey(const Key('translation-prompt')));
    await press(tester, find.byKey(const Key('translation-presets-close')));
    expect(dialer.calls, isEmpty);
    // US translation prefill switched to the independently remembered CN region.
    await press(tester, find.byKey(const Key('dial-country')));
    await press(tester, find.byKey(const Key('dial-country-g20-US')));
    await press(tester, find.byKey(const Key('dial-call')));
    expect(find.text('实时翻译通话'), findsNothing);
    expect(dialer.calls, ['+12025550123']);
    expect(find.text('已交给系统电话，请在系统界面确认'), findsOneWidget);
  });
  testWidgets(
    'unresolved location model entry opens country picker for authorization',
    (tester) async {
      final dialer = RecordingDialer();
      await open(
        tester,
        dialer,
        access: const TranslationAccess(countryIso: null, forced: false),
      );
      expect(find.text('位置待确认'), findsOneWidget);
      await press(tester, find.byKey(const ValueKey('translation-model-open')));
      expect(find.text('选择国家或地区'), findsOneWidget);
      expect(dialer.calls, isEmpty);
    },
  );
  testWidgets(
    'formal translation action respects offline without system fallback',
    (tester) async {
      final dialer = RecordingDialer();
      await open(tester, dialer, network: DeveloperNetworkMode.offline);
      await press(tester, find.byKey(const Key('translation-presets-open')));
      await press(tester, find.byKey(const Key('translation-prompt')));
      await press(tester, find.byKey(const Key('translation-presets-close')));
      await press(tester, find.byKey(const Key('dial-call')));
      expect(find.text('无网络连接'), findsOneWidget);
      await press(tester, find.text('重试'));
      expect(find.text('当前仍为断网模拟，可在开发者功能切换'), findsOneWidget);
      await press(tester, find.text('关闭'));
      expect(find.text('国外翻译媒体与呼叫链路尚未接入，没有发起通话'), findsNothing);
      expect(dialer.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'overseas model region retained after back, no domestic options',
    (tester) async {
      final dialer = RecordingDialer();
      await open(tester, dialer);
      await press(tester, find.byKey(const Key('translation-presets-open')));
      expect(find.text('海外模型与服务区域'), findsNothing);
      await press(tester, find.byKey(const Key('translation-presets-close')));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TranslationDialerRoute)),
      );
      Future<void> openSettings() async {
        Navigator.of(
          tester.element(find.byType(TranslationDialerRoute)),
        ).push<void>(
          MaterialPageRoute(
            builder: (_) => RouteProviderScope(
              container: container,
              child: TranslationSettingsRoute(
                controller: container.read(translationSetupProvider.notifier),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openSettings();
      expect(find.text('Qwen'), findsNothing);
      await press(tester, find.text('GPT Live Translate'));
      await press(
        tester,
        find.byKey(const ValueKey('translation-setting-region-JP')),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openSettings();
      expect(
        tester
            .widget<NativeSettingChoice>(
              find.byKey(const ValueKey('translation-setting-model-OPENAI')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<NativeSettingCard>(
              find.byKey(const ValueKey('translation-setting-region-JP')),
            )
            .value,
        '已选择',
      );
      expect(dialer.calls, isEmpty);
    },
  );
  testWidgets('empty number opens presets then rejects without any call', (
    tester,
  ) async {
    final dialer = RecordingDialer();
    await open(tester, dialer, number: null);
    await press(tester, find.byKey(const Key('dial-call')));
    expect(find.text('实时翻译通话'), findsOneWidget);
    await press(tester, find.widgetWithText(FilledButton, '实时翻译呼叫'));
    expect(find.text('请输入正确的手机号码'), findsOneWidget);
    expect(find.text('实时翻译通话'), findsNothing);
    expect(dialer.calls, isEmpty);
  });
}
