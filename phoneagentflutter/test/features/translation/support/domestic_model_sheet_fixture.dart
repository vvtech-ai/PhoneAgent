import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import '../../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'dart:async';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/domestic_translation_quality_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/domestic_translation_settings_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_provider_catalog.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/presentation/controller/domestic_translation_settings_controller.dart';
import 'package:phone_agent/features/translation/presentation/widgets/domestic_translation_dial_summary.dart';

final sheetAccess = StateProvider<TranslationAccess>(
  (_) => const TranslationAccess(countryIso: 'CN', forced: false),
);
final sheetLogin = StateProvider<int>((_) => 0);

class SheetRepository implements DomesticProviderRepository {
  String selected = 'QWEN_OMNI_PLUS';
  bool failLoad = false, failSelect = false, available = true;
  int reads = 0, switches = 0;
  Completer<DomesticProviderCatalog>? pending;
  DomesticProviderCatalog catalog(String id) => DomesticProviderCatalog(
    activeWireId: id,
    options: [
      for (final wire in ['QWEN_OMNI_PLUS', 'DOUBAO'])
        DomesticProviderOption(
          wireId: wire,
          engine: wire == 'DOUBAO' ? 'DOUBAO' : 'QWEN',
          active:
              domesticTranslationModel(wire) == domesticTranslationModel(id),
          configured: true,
          available: wire != 'DOUBAO' || available,
          statusMessage: '',
          billingMultiplier: wire == 'DOUBAO' ? 1.1 : 1,
        ),
    ],
  );
  @override
  Future<DomesticProviderCatalog> load() async {
    reads++;
    if (failLoad) throw StateError('synthetic load failure');
    return catalog(selected);
  }

  @override
  Future<DomesticProviderCatalog> select(String wireId) async {
    switches++;
    if (failSelect) throw StateError('synthetic switch failure');
    final result = await (pending?.future ?? Future.value(catalog(wireId)));
    selected = result.activeWireId;
    return result;
  }
}

Future<ProviderContainer> mountSheetDialer(
  WidgetTester tester,
  SheetRepository repository, {
  double scale = 1,
  TargetPlatform platform = TargetPlatform.android,
  TranslationModelProbe? probe,
  Future<TranslationDirectory> Function()? loadDirectory,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationSetupProvider.overrideWith((ref) {
          final controller = TranslationSetupController();
          controller.directory(syntheticTranslationDirectory);
          return controller;
        }),
        translationDirectoryProvider.overrideWith(
          (ref) =>
              loadDirectory?.call() ??
              Future.value(syntheticTranslationDirectory),
        ),
        loginEpochProvider.overrideWith((ref) => ref.watch(sheetLogin)),
        domesticTranslationModelProbeProvider.overrideWithValue(
          probe ?? SheetProbe(),
        ),
        translationAccessProvider.overrideWith((ref) => ref.watch(sheetAccess)),
        domesticTranslationSettingsProvider.overrideWith((ref) {
          final generation = ref.watch(sheetLogin);
          final controller = DomesticTranslationSettingsController(
            repository: repository,
            isCurrent: () => ref.read(sheetLogin) == generation,
          );
          controller.load();
          return controller;
        }),
      ],
      child: MaterialApp(
        theme: ThemeData(
          platform: platform,
          fontFamily: const bool.fromEnvironment('MODEL_SHEET_CAPTURE')
              ? 'ReferenceText'
              : null,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              const Text('拨号页号码 13800000000'),
              const DomesticTranslationDialSummary(
                enabled: true,
                languages: '我方中文 ⇄ 对方英语',
                busy: false,
                onLanguages: null,
              ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('其他页面')),
                    ),
                  ),
                  child: const Text('打开其他页面'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(DomesticTranslationDialSummary)),
  );
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('translation-model-open')));
  await tester.pumpAndSettle();
}

Future<void> selectDoubao(WidgetTester tester) async {
  final option = find.byKey(const ValueKey('domestic-model-DOUBAO'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

class SheetProbe implements TranslationModelProbe {
  int calls = 0;
  @override
  Future<TranslationModelSample> sample(String model) async {
    calls++;
    return TranslationModelSample.reachable(model == 'QWEN' ? 140 : 350);
  }
}
