import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/translation/data/preview_translation_configuration.dart';
import 'dart:async';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_model_selection_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/domestic_translation_dial.dart';
import 'package:phone_agent/app/domestic_translation_settings_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_provider_catalog.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/domestic_translation_settings_controller.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_location_controller.dart';

class Location implements TranslationLocationSource, TranslationLocationStore {
  Location(this.iso);
  final String iso;
  Future<TranslationLocationResult>? refresh;
  @override
  Future<TrustedTranslationLocation?> read() async =>
      TrustedTranslationLocation(iso, 1);
  @override
  Future<void> write(TrustedTranslationLocation value) async {}
  @override
  Future<TranslationLocationResult> locate() async =>
      refresh ?? (throw StateError('No device action'));
  @override
  Future<void> openSettings() async => throw StateError('No device action');
  @override
  Future<void> cancel() async {}
}

class Models implements DomesticProviderRepository {
  Models(this.mode);
  final String mode;
  @override
  Future<DomesticProviderCatalog> load() async {
    if (mode == 'loading') return Completer<DomesticProviderCatalog>().future;
    if (mode == 'failed') throw StateError('Synthetic model failure');
    return DomesticProviderCatalog(
      activeWireId: 'QWEN_OMNI_PLUS',
      options: [
        DomesticProviderOption(
          wireId: 'QWEN_OMNI_PLUS',
          engine: 'QWEN',
          active: true,
          configured: true,
          available: mode != 'unavailable',
          statusMessage: '',
        ),
      ],
    );
  }

  @override
  Future<DomesticProviderCatalog> select(String wireId) async =>
      throw StateError('No network');
}

void main() {
  testWidgets('trusted CN remains admissible during pending refresh', (
    tester,
  ) async {
    await verifyAdmission(tester, refreshing: true);
  });
  for (final storage in ['missing', 'pending', 'corrupt', 'failed']) {
    for (final target in ['CN', 'US']) {
      testWidgets('immediate $target dial ignores $storage SIP storage', (
        tester,
      ) async {
        await verifyAdmission(tester, target: target, storage: storage);
      });
    }
  }
  for (final mode in ['unloaded', 'loading', 'failed', 'unavailable']) {
    testWidgets('$mode model still prevents domestic session', (tester) async {
      await verifyAdmission(tester, modelMode: mode);
    });
  }
  testWidgets(
    'non-CN bound local model uses SIP instead of geographic rejection',
    (tester) async {
      await verifyAdmission(tester, locationIso: 'US');
    },
  );
}

Future<void> verifyAdmission(
  WidgetTester tester, {
  String target = 'US',
  bool refreshing = false,
  String locationIso = 'CN',
  String storage = 'missing',
  String modelMode = 'ready',
}) async {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  var storageReads = 0;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    storageReads++;
    switch (storage) {
      case 'pending':
        return Completer<Object?>().future;
      case 'failed':
        throw PlatformException(code: 'synthetic_storage_failed');
      case 'corrupt':
        return '{invalid old preference';
      default:
        return null;
    }
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  final location = Location(locationIso);
  final locationOwner = TranslationLocationController(location, location);
  final modelOwner = DomesticTranslationSettingsController(
    repository: Models(modelMode),
    isCurrent: () => true,
  );
  await locationOwner.load();
  if (refreshing) {
    location.refresh = Completer<TranslationLocationResult>().future;
    unawaited(locationOwner.locate());
    expect(locationOwner.snapshot.refreshing, isTrue);
  }
  if (modelMode == 'loading') {
    unawaited(modelOwner.load());
  } else if (modelMode != 'unloaded') {
    await modelOwner.load();
  }
  TranslationCallPlan? plan;
  var overseasCreates = 0;
  Object? result;
  final binding = TranslationDialSessionBinding(
    create: (_) {
      overseasCreates++;
      throw StateError('Overseas must not run');
    },
    createDomestic: (frozen, context) {
      plan = frozen;
      expect(context.countryIso, target);
      expect(context.targetName, 'Synthetic receiver');
      throw StateError('Synthetic admission only');
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationPreferenceStoreProvider.overrideWithValue(
          PreviewTranslationPreferenceStore(),
        ),
        translationLocationProvider.overrideWith((_) => locationOwner),
        selectedTranslationModelProvider.overrideWithValue(
          modelMode == 'ready'
              ? syntheticTranslationDirectory.model('QWEN_OMNI_PLUS')
              : null,
        ),
        domesticTranslationSettingsProvider.overrideWith((_) => modelOwner),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                try {
                  await createDomesticTranslationDial(
                    ref,
                    binding,
                    rawNumber: target == 'CN' ? '13800000000' : '2025550123',
                    countryIso: target,
                    displayName: 'Synthetic receiver',
                    preferences: const TranslationPreferences(enabled: true),
                  );
                } catch (failure) {
                  result = failure;
                }
              },
              child: const Text('Synthetic admission'),
            ),
          ),
        ),
      ),
    ),
  );
  // Tap immediately: no account initialization or settling is required.
  await tester.tap(find.text('Synthetic admission'));
  await tester.pump();
  expect(overseasCreates, 0);
  expect(storageReads, 0);
  if (modelMode == 'ready') {
    expect(result, isA<StateError>());
    expect(
      plan?.transport,
      target == locationIso
          ? TranslationCallTransport.domesticSip
          : TranslationCallTransport.internationalSip,
    );
    expect(plan?.provider, 'QWEN');
    expect(plan?.modelId, 'QWEN_OMNI_PLUS');
    expect(plan?.sipAccountId, '21311802');
    expect(
      plan?.networkNumber,
      target == 'CN' ? '13800000000' : '0012025550123',
    );
    expect(plan?.target, target == 'CN' ? '+8613800000000' : '+12025550123');
  } else {
    expect(result, isA<TranslationPlanFailure>());
    expect(plan, isNull);
    final failure = result! as TranslationPlanFailure;
    expect(failure.message, isNot(contains('SIP账号')));
    expect(
      failure.code,
      locationIso == 'CN'
          ? 'DOMESTIC_SETTINGS_UNAVAILABLE'
          : 'LOCATION_UNAVAILABLE',
    );
  }
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}
