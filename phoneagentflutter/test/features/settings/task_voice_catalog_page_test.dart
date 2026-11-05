import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/task_voice_preview_providers.dart';
import 'package:phone_agent/features/settings/presentation/controller/task_voice_preview_controller.dart';
import 'package:phone_agent/features/settings/presentation/widgets/task_voice_settings_section.dart';
import '../../support/synthetic_account_api.dart';

Map<String, Object?> catalog(String voice) => {
  'modelId': 'task-tts',
  'selectedVoice': voice,
  'defaultVoice': 'Ethan',
  'voices': [
    {
      'voice': 'Ethan',
      'displayName': 'Ethan',
      'description': '合成男声',
      'defaultVoice': true,
    },
    {
      'voice': 'Maia',
      'displayName': 'Maia',
      'description': '合成女声',
      'defaultVoice': false,
    },
    {'voice': 'Andre', 'displayName': 'Andre', 'defaultVoice': false},
  ],
};

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform displays current and available SDK voices then saves Maia',
      (tester) async {
        final wire = SyntheticAccountApi()..data = catalog('Ethan');
        addTearDown(wire.api.close);
        wire.beforeResponse = (request) async {
          if (request.method == 'PUT') wire.data = catalog('Maia');
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginEpochProvider.overrideWithValue(1),
              accountApiProvider.overrideWithValue(wire.api),
              taskVoicePreviewProvider.overrideWith(
                (ref, owner) => TaskVoicePreviewController(
                  (_) =>
                      (_, __) => throw StateError('no preview requested'),
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const Scaffold(body: TaskVoiceSettingsSection()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ethan'), findsOneWidget);
        expect(find.text('加载失败'), findsNothing);
        await tester.tap(find.byKey(const Key('task-voice-entry')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('task-voice-Ethan')), findsOneWidget);
        expect(find.byKey(const ValueKey('task-voice-Maia')), findsOneWidget);
        expect(find.byKey(const ValueKey('task-voice-Andre')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('task-voice-Maia')));
        await tester.pumpAndSettle();
        expect(find.text('已选择 Maia'), findsOneWidget);
        expect(wire.requests.last.method, 'PUT');
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(find.text('Maia'), findsOneWidget);
      },
    );
  }
}
