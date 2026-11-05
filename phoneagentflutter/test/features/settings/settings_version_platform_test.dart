import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/about_providers.dart';
import 'package:phone_agent/app/domestic_translation_settings_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_route.dart';
import '../../support/initialized_identity.dart';
import '../../support/shell_fakes.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  testWidgets(
    'settings home constructs neither version metadata nor manual update',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final metadata = _MissingMetadata();
      final update = StartupRepositoryFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...initializedIdentityOverrides(),
            translationSetupProvider.overrideWith(
              (_) => throw StateError('Home must not construct overseas setup'),
            ),
            translationLocationProvider.overrideWith(
              (_) => throw StateError(
                'Home must not resolve translation location',
              ),
            ),
            domesticTranslationSettingsProvider.overrideWith(
              (_) => throw StateError(
                'Home must not construct domestic model settings',
              ),
            ),
            logEntryControllerProvider.overrideWith(
              (_) => throw StateError('Settings home must not construct logs'),
            ),
            aboutMetadataSourceProvider.overrideWithValue(metadata),
            callModelRepositoryProvider.overrideWithValue(
              FakeCallModelRepository(),
            ),
            appUpdateControllerProvider.overrideWith(
              (_) => throw StateError('Home must not construct manual update'),
            ),
            appUpdateRepositoryProvider.overrideWithValue(update),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SettingsRoute(onIdentity: () {}, onModels: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('海外模型与服务区域'), findsNothing);
      expect(
        find.byKey(const Key('settings-overseasTranslation')),
        findsNothing,
      );
      expect(find.byKey(const Key('settings-domestic-model')), findsNothing);
      expect(find.text('实时翻译通话'), findsNothing);
      expect(find.byKey(const Key('settings-update')), findsNothing);
      expect(metadata.reads, 0);
      expect(find.byKey(const Key('settings-logs')), findsNothing);
      expect(find.byKey(const Key('settings-trustedCaller')), findsOneWidget);
      expect(update.checks, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}

class _MissingMetadata implements InstalledAppSource {
  int reads = 0;
  @override
  Future<InstalledApp> read() async {
    reads++;
    throw StateError('synthetic metadata unavailable');
  }
}
