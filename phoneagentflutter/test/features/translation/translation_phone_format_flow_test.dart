import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import '../../../tool/previews/shell_translation_preview.dart';
import '../../support/translation_directory_fixture.dart';

final _epoch = StateProvider<int>((ref) => 1);
void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform format cancel, stale login and continue without duplicate create',
      (tester) async {
        final ports = ShellTranslationPreviewPorts(
          originalAudio: () => const OriginalAudioSettings(),
        );
        ports.preferences.value = const TranslationPreferences(
          prompt: false,
          translationCountry: 'US',
        );
        final dto = translationOptionsFixture();
        for (final country in dto['countries'] as List) {
          if ((country as Map)['countryCode'] == 'US') {
            country['phoneRegex'] = r'^202[0-9]{7}$';
          }
        }
        var creates = 0;
        var confirmed = false;
        Widget application({bool epochOverride = false}) => ProviderScope(
          overrides: [
            ...ports.overrides.skip(1),
            translationDirectoryProvider.overrideWith(
              (ref) async => ApiTranslationDirectory.decode(dto),
            ),
            if (epochOverride)
              loginEpochProvider.overrideWith((ref) => ref.watch(_epoch)),
            networkAvailabilitySourceProvider.overrideWithValue(
              const UnknownNetworkAvailability(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: TranslationDialerRoute(
              number: '123456789',
              countryIso: 'US',
              sessionBinding: TranslationDialSessionBinding(
                create: (request) {
                  creates++;
                  confirmed = request.allowUnverifiedNumber;
                  throw StateError('synthetic; no network');
                },
              ),
            ),
          ),
        );
        await tester.pumpWidget(application(epochOverride: true));
        await tester.pumpAndSettle();
        Future<void> dial() async {
          final finder = find.byKey(const Key('dial-call'));
          await tester.ensureVisible(finder);
          final callback = tester.widget<InkWell>(finder).onTap!;
          callback();
          callback();
          await tester.pumpAndSettle();
          expect(find.text('号码格式提醒'), findsOneWidget);
        }

        await dial();
        await tester.tap(find.byKey(const Key('translation-phone-cancel')));
        await tester.pumpAndSettle();
        expect(creates, 0);
        await dial();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TranslationDialerRoute)),
        );
        container.read(_epoch.notifier).state++;
        await tester.pump();
        await tester.tap(find.byKey(const Key('translation-phone-continue')));
        await tester.pumpAndSettle();
        expect(creates, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(application());
        await tester.pumpAndSettle();
        await dial();
        await tester.tap(find.byKey(const Key('translation-phone-continue')));
        await tester.pumpAndSettle();
        expect(creates, 1);
        expect(confirmed, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
