import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/app/domestic_translation_quality_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  for (final country in ['CN', 'US']) {
    testWidgets(
      '$country mixed transport models show their own quality samples',
      (tester) async {
        final dto = translationOptionsFixture();
        (dto['models'] as List).add(<String, Object>{
          ...Map<String, Object>.from((dto['models'] as List).first as Map),
          'modelId': 'qwen-international',
          'providerCode': 'dashscope-intl',
          'transport': 'BACKEND_WEBRTC',
        });
        for (final row in dto['countries'] as List) {
          if ((row as Map)['countryCode'] == country) {
            row['availableModelIds'] = ['QWEN_OMNI_PLUS', 'qwen-international'];
          }
        }
        final directory = ApiTranslationDirectory.decode(dto);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginEpochProvider.overrideWith((ref) => 1),
              translationAccessProvider.overrideWithValue(
                TranslationAccess(countryIso: country, forced: false),
              ),
              translationDirectoryProvider.overrideWith(
                (ref) async => directory,
              ),
              translationSetupProvider.overrideWith(
                (ref) => TranslationSetupController()..directory(directory),
              ),
              domesticTranslationModelQualityProvider.overrideWith(
                (ref) async => {
                  'QWEN_OMNI_PLUS': TranslationModelSample.reachable(250),
                },
              ),
              translationModelQualityProvider('DEFAULT').overrideWith(
                (ref) async => {'QWEN': TranslationModelSample.reachable(90)},
              ),
            ],
            child: MaterialApp(
              home: TranslationModelSheet(
                selected: 'qwen-international',
                region: 'DEFAULT',
                domestic: country == 'CN',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final prefix = country == 'CN' ? 'domestic' : 'translation';
        NativeTranslationModelOption option(String id) =>
            tester.widget(find.byKey(ValueKey('$prefix-model-$id')));
        expect(option('QWEN_OMNI_PLUS').sample!.latencyMs, 250);
        expect(option('qwen-international').sample!.latencyMs, 90);
        expect(option('qwen-international').onSelect, isNotNull);
        expect(
          option('OPENAI').sample!.quality,
          TranslationQuality.unavailable,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
