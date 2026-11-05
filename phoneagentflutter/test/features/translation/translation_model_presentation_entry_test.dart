import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/domestic_translation_quality_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_model_selection_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/widgets/domestic_translation_model_sheet.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';
import '../../support/translation_directory_fixture.dart';
import 'support/domestic_model_sheet_fixture.dart' show SheetProbe;

void main() {
  for (final domestic in [true, false]) {
    testWidgets(
      'published order survives default, quality and explicit choice domestic=$domestic',
      (tester) async {
        final dto = translationOptionsFixture()
          ..['defaultTranslationModelId'] = domestic ? 'DOUBAO' : 'OPENAI';
        final rows = dto['models'] as List;
        dto['models'] = [rows[3], rows[1], rows[2], rows[0]];
        final directory = ApiTranslationDirectory.decode(dto);
        final setup = TranslationSetupController()..directory(directory);
        final container = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWith((_) => 1),
            translationSetupProvider.overrideWith((_) => setup),
            translationDirectoryProvider.overrideWith((_) async => directory),
            translationAccessProvider.overrideWith(
              (_) => TranslationAccess(
                countryIso: domestic ? 'CN' : 'US',
                forced: false,
              ),
            ),
            domesticTranslationModelProbeProvider.overrideWithValue(
              SheetProbe(),
            ),
            translationModelQualityProvider('DEFAULT').overrideWith(
              (_) async => {
                'OPENAI': TranslationModelSample.reachable(900),
                'GEMINI': TranslationModelSample.reachable(10),
              },
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(translationDirectoryProvider.future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => domestic
                        ? showDomesticTranslationModelSheet(context)
                        : showTranslationModelSheet(context, setup),
                    child: const Text('选择模型'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(selectedTranslationModelProvider)?.id,
          domestic ? 'DOUBAO' : 'OPENAI',
        );
        expect(setup.snapshot.domesticModelId, isEmpty);
        expect(setup.snapshot.overseasModelId, isEmpty);
        await tester.tap(find.text('选择模型'));
        await tester.pumpAndSettle();
        List<NativeTranslationModelOption> options() => tester
            .widgetList<NativeTranslationModelOption>(
              find.byType(NativeTranslationModelOption),
            )
            .toList();
        expect(options().map((item) => item.name), [
          'Gemini Live',
          'Doubao',
          'GPT Live Translate',
          'Qwen3.5',
        ]);
        expect(
          options().singleWhere((item) => item.selected).name,
          domestic ? 'Doubao' : 'GPT Live Translate',
        );
        final key = ValueKey(
          domestic
              ? 'domestic-model-QWEN_OMNI_PLUS'
              : 'translation-model-GEMINI',
        );
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(
          domestic
              ? setup.snapshot.domesticModelId
              : setup.snapshot.overseasModelId,
          domestic ? 'QWEN_OMNI_PLUS' : 'GEMINI',
        );
        await tester.tap(find.text('选择模型'));
        await tester.pumpAndSettle();
        expect(options().map((item) => item.name), [
          'Gemini Live',
          'Doubao',
          'GPT Live Translate',
          'Qwen3.5',
        ]);
        expect(
          options().singleWhere((item) => item.selected).name,
          domestic ? 'Qwen3.5' : 'Gemini Live',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
