import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_dial_summary.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  testWidgets('dial summary resolves server labels and new language codes', (
    tester,
  ) async {
    final dto = translationOptionsFixture();
    ((dto['languages'] as List).first as Map)['displayName'] = '服务器中文名';
    (dto['languages'] as List).add({'code': 'it', 'displayName': '意大利语'});
    final directory = ApiTranslationDirectory.decode(dto);
    final setup = TranslationSetupController()..directory(directory);
    setup.language('it', caller: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationSetupProvider.overrideWith((_) => setup),
          translationDirectoryProvider.overrideWith((_) async => directory),
        ],
        child: const MaterialApp(home: TranslationDialerRoute(preview: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('我方 服务器中文名  ⇄  意大利语 对方'), findsOneWidget);
    setup.enable(false);
    await tester.pumpAndSettle();
    expect(find.text('实时翻译  关'), findsOneWidget);
    setup.enable(true);
    setup.language('en', caller: false);
    await tester.pumpAndSettle();
    expect(find.text('我方 服务器中文名  ⇄  英文 对方'), findsOneWidget);
    final summary = tester.widget<NativeTranslationDialSummary>(
      find.byType(NativeTranslationDialSummary),
    );
    expect(
      summary.multiplier,
      isNull,
    ); // No selected directory model, no foreign rate.
    expect(tester.takeException(), isNull);
  });
}
