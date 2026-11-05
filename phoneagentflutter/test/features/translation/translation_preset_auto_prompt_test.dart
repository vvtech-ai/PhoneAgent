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

class _System implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform empty number opens presets before number notice', (
      tester,
    ) async {
      final ports = ShellTranslationPreviewPorts(
        originalAudio: () => const OriginalAudioSettings(),
      );
      ports.preferences.value = const TranslationPreferences(
        enabled: true,
        prompt: true,
        translationCountry: 'US',
        overseasModelId: 'OPENAI',
      );
      final system = _System();
      await tester.pumpWidget(
        ProviderScope(
          overrides: ports.overrides,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: TranslationDialerRoute(systemDialer: system),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('实时翻译通话'), findsOneWidget);
      expect(find.text('请输入正确的电话号码'), findsNothing);
      expect(system.calls, 0);
      await tester.tap(find.byKey(const Key('translation-presets-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final enabled in [false, true]) {
      for (final prompt in [false, true]) {
        testWidgets(
          '$platform enabled=$enabled prompt=$prompt: native auto and manual flow',
          (tester) async {
            final ports = ShellTranslationPreviewPorts(
              originalAudio: () => const OriginalAudioSettings(),
            );
            ports.preferences.value = TranslationPreferences(
              enabled: enabled,
              prompt: prompt,
              provider: 'OPENAI',
              normalCountry: 'US',
              translationCountry: 'US',
              overseasModelId: 'OPENAI',
            );
            final system = _System();
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
                            number: '+12025550123',
                            countryIso: 'US',
                            systemDialer: system,
                            sessionBinding: TranslationDialSessionBinding(
                              create: (_) {
                                creates++;
                                throw StateError(
                                  'synthetic stop before business calls',
                                );
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
            Future<void> press(Finder target) async {
              await tester.ensureVisible(target);
              await tester.tap(target);
              await tester.pumpAndSettle();
            }

            await press(find.text('open'));
            final container = ProviderScope.containerOf(
              tester.element(find.byType(TranslationDialerRoute)),
            );
            await press(find.byKey(const Key('dial-call')));
            final automatic = enabled && prompt;
            expect(
              find.text('实时翻译通话'),
              automatic ? findsOneWidget : findsNothing,
            );
            expect(system.calls, enabled ? 0 : 1);
            expect(creates, enabled && !prompt ? 1 : 0);
            if (automatic) {
              await press(find.byKey(const Key('translation-presets-close')));
              expect(creates, 0);
              expect(system.calls, 0);
            }
            // Manual entry remains available with the same controls and preference.
            await press(find.byKey(const Key('translation-presets-open')));
            expect(find.text('实时翻译通话'), findsOneWidget);
            expect(
              find.byKey(const Key('translation-enabled')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('translation-prompt')), findsOneWidget);
            final manualCalls = system.calls, manualCreates = creates;
            await press(
              find.widgetWithText(FilledButton, enabled ? '实时翻译呼叫' : '普通呼叫'),
            );
            expect(find.text('实时翻译通话'), findsNothing);
            expect(system.calls, manualCalls + (enabled ? 0 : 1));
            expect(creates, manualCreates + (enabled ? 1 : 0));
            expect(
              container.read(translationSetupProvider).value.prompt,
              prompt,
            );
            expect(
              container.read(translationSetupProvider).value.enabled,
              enabled,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
