import 'package:phone_agent/app/business_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import '../../../tool/previews/shell_translation_preview.dart';

final _testEpoch = StateProvider<int?>((_) => 1);

class _System implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

void main() {
  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final entry in ['dial', 'presets']) {
      testWidgets('$platform $entry cross-border cancel then continue once', (
        tester,
      ) async {
        final ports = ShellTranslationPreviewPorts(
          originalAudio: () => const OriginalAudioSettings(),
        );
        ports.preferences.value = const TranslationPreferences(
          prompt: false,
          provider: 'OPENAI',
          translationCountry: 'CN',
          overseasModelId: 'OPENAI',
        );
        var creates = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...ports.overrides,
              networkAvailabilitySourceProvider.overrideWithValue(
                const UnknownNetworkAvailability(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TranslationDialerRoute(
                        number: '+8613800000000',
                        countryIso: 'CN',
                        systemDialer: _System(),
                        sessionBinding: TranslationDialSessionBinding(
                          create: (_) {
                            creates++;
                            throw StateError('synthetic');
                          },
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await press(tester, find.text('open'));
        Future<void> attempt() async {
          if (entry == 'presets') {
            await press(
              tester,
              find.byKey(const Key('translation-presets-open')),
            );
            await press(tester, find.widgetWithText(FilledButton, '实时翻译呼叫'));
          } else {
            await tester.ensureVisible(find.byKey(const Key('dial-call')));
            final callback = tester
                .widget<InkWell>(find.byKey(const Key('dial-call')))
                .onTap!;
            callback();
            callback();
            await tester.pumpAndSettle();
          }
        }

        await attempt();
        expect(find.text('跨境通话质量提示'), findsOneWidget);
        expect(creates, 0);
        await press(tester, find.byKey(const Key('cross-border-cancel')));
        expect(creates, 0);
        expect(find.byType(TranslationDialerRoute), findsOneWidget);
        await attempt();
        await press(tester, find.byKey(const Key('cross-border-continue')));
        expect(creates, 1);
        expect(find.text('跨境通话质量提示'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scenario in [
    'same',
    'ordinary',
    'simulated',
    'changed',
    'account',
    'left',
  ]) {
    testWidgets(
      '$scenario call admission uses current countries and lifecycle',
      (tester) async {
        final ports = ShellTranslationPreviewPorts(
          originalAudio: () => const OriginalAudioSettings(),
        );
        ports.preferences.value = TranslationPreferences(
          enabled: scenario != 'ordinary',
          prompt: false,
          provider: 'OPENAI',
          translationCountry: 'US',
          normalCountry: 'US',
          overseasModelId: 'OPENAI',
          simulatedCountryIso:
              ['simulated', 'changed', 'account', 'left'].contains(scenario)
              ? 'JP'
              : '',
        );
        var creates = 0;
        final system = _System();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...ports.overrides,
              loginEpochProvider.overrideWith((ref) => ref.watch(_testEpoch)),
              networkAvailabilitySourceProvider.overrideWithValue(
                const UnknownNetworkAvailability(),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TranslationDialerRoute(
                        number: '+12025550123',
                        countryIso: 'US',
                        systemDialer: system,
                        sessionBinding: TranslationDialSessionBinding(
                          create: (_) {
                            creates++;
                            throw StateError('synthetic');
                          },
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await press(tester, find.text('open'));
        final routeContext = tester.element(
          find.byType(TranslationDialerRoute),
        );
        final navigator = Navigator.of(routeContext);
        final route = ModalRoute.of(routeContext)!;
        final container = ProviderScope.containerOf(routeContext);
        await press(tester, find.byKey(const Key('dial-call')));
        if (scenario == 'same' || scenario == 'ordinary') {
          expect(find.text('跨境通话质量提示'), findsNothing);
          expect(creates, scenario == 'same' ? 1 : 0);
          expect(system.calls, scenario == 'ordinary' ? 1 : 0);
        } else {
          expect(find.text('跨境通话质量提示'), findsOneWidget);
          expect(creates, 0);
          if (scenario == 'changed') {
            container
                .read(translationSetupProvider.notifier)
                .language('ja', caller: true);
            await tester.pumpAndSettle();
          }
          if (scenario == 'account') {
            container.read(_testEpoch.notifier).state = 2;
            await tester.pumpAndSettle();
          }
          if (scenario == 'left') {
            navigator.removeRoute(route);
            await tester.pumpAndSettle();
          }
          await press(tester, find.byKey(const Key('cross-border-continue')));
          expect(creates, scenario == 'simulated' ? 1 : 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
