import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets(
    'settings home exposes original audio without domestic model page',
    (tester) async {
      SettingsDestination? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              onOpen: (value) => opened = value,
              developer: false,
              modelSummary: '',
              originalSummary: '设置',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('settings-domestic-model')), findsNothing);
      expect(find.text('实时翻译通话'), findsNothing);
      expect(find.byKey(const Key('settings-sip-accounts')), findsNothing);
      await tester.tap(find.byKey(const Key('settings-originalAudio')));
      expect(opened, SettingsDestination.originalAudio);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
