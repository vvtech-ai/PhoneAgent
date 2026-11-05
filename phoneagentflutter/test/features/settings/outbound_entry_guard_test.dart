import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/presentation/pages/outbound_number_route.dart';
import 'package:phone_agent/features/settings/presentation/widgets/outbound_number_entry.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform old entry cannot reset or duplicate editor', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          developerModeProvider.overrideWith((_) => true),
          outboundNumberRepositoryProvider.overrideWithValue(
            PreviewOutboundNumberRepository(number: '2025550123'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(body: OutboundNumberEntry()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final open = tester
          .widget<NativeSettingCard>(find.byType(NativeSettingCard))
          .onTap!;
      open();
      open();
      await tester.pumpAndSettle();
      expect(
        find.byType(OutboundNumberRoute, skipOffstage: false),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '2025550199');
      open();
      await tester.pumpAndSettle();
      expect(container.read(outboundNumberProvider).draft, '2025550199');
      expect(
        find.byType(OutboundNumberRoute, skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();
      expect(container.read(outboundNumberProvider).draft, '2025550123');
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform disposed entry callback is harmless', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            developerModeProvider.overrideWith((_) => true),
            outboundNumberRepositoryProvider.overrideWithValue(
              PreviewOutboundNumberRepository(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(body: OutboundNumberEntry()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final open = tester
          .widget<NativeSettingCard>(find.byType(NativeSettingCard))
          .onTap!;
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      open();
      await tester.pumpAndSettle();
      expect(find.text('replacement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
