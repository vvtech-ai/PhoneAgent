import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_model_selection_providers.dart';
import 'package:phone_agent/app/translation_quality_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  for (final preview in [false, true]) {
    testWidgets(
      'opening model selection refreshes published options only when live preview=$preview',
      (tester) async {
        var reads = 0;
        var qualityReads = 0;
        final fresh = Completer<TranslationDirectory>();
        final setup = TranslationSetupController();
        addTearDown(setup.dispose);
        final container = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWith((ref) => 1),
            translationDirectoryProvider.overrideWith((ref) async {
              return ++reads == 1
                  ? syntheticTranslationDirectory
                  : fresh.future;
            }),
            selectedTranslationModelProvider.overrideWith((ref) => null),
            translationAccessProvider.overrideWith(
              (ref) => const TranslationAccess(countryIso: 'US', forced: false),
            ),
            translationBillingProvider.overrideWith((ref) async => {}),
            translationModelQualityProvider('DEFAULT').overrideWith((
              ref,
            ) async {
              qualityReads++;
              return {};
            }),
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
                    onPressed: () => showTranslationModelSheet(
                      context,
                      setup,
                      preview: preview,
                    ),
                    child: const Text('选择模型'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('选择模型'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(reads, preview ? 1 : 2);
        if (preview) return;
        expect(find.text('GPT Live Translate'), findsNothing);
        expect(qualityReads, 1);
        final dto = translationOptionsFixture();
        (dto['models'] as List).removeWhere(
          (row) => (row as Map)['modelId'] == 'OPENAI',
        );
        for (final row in dto['countries'] as List) {
          ((row as Map)['availableModelIds'] as List).remove('OPENAI');
        }
        fresh.complete(ApiTranslationDirectory.decode(dto));
        await tester.pumpAndSettle();
        expect(find.text('GPT Live Translate'), findsNothing);
        expect(find.text('Gemini Live'), findsOneWidget);
        expect(reads, 2);
        expect(qualityReads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
