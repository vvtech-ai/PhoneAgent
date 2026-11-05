import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_tools_route.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/data/preview_translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import '../features/translation/translation_preferences_persistence_test.dart';
import 'translation_directory_fixture.dart';

Future<
  ({
    ProviderContainer container,
    MemoryTranslationStore store,
    PreviewTranslationLocation location,
  })
>
openDeveloperTools(
  WidgetTester tester, {
  bool unlocked = true,
  TargetPlatform? platform,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(430, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = MemoryTranslationStore();
  final location = PreviewTranslationLocation()
    ..cached = TrustedTranslationLocation('CN', 100);
  final container = ProviderContainer(
    overrides: [
      developerModeProvider.overrideWith((_) => unlocked),
      outboundNumberRepositoryProvider.overrideWithValue(
        PreviewOutboundNumberRepository(),
      ),
      translationPreferenceStoreProvider.overrideWithValue(store),
      translationLocationStoreProvider.overrideWithValue(location),
      translationLocationSourceProvider.overrideWithValue(location),
      translationDirectoryProvider.overrideWith(
        (_) async =>
            ApiTranslationDirectory.decode(translationOptionsFixture()),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const DeveloperToolsRoute(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, store: store, location: location);
}
