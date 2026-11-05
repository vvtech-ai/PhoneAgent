import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/native_original_audio_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform audio levels have names values and native actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        var volume = 90, gain = 40, changes = 0, enabled = true;
        Future<void> show() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, update) => Column(
                    children: [
                      NativeAudioLevel(
                        label: '纯原声播放声音大小',
                        value: volume,
                        max: 100,
                        sliderKey: const Key('volume'),
                        onChanged: enabled
                            ? (v) => update(() {
                                volume = v.round();
                                changes++;
                              })
                            : null,
                      ),
                      NativeAudioLevel(
                        label: '混声时原声比例',
                        value: gain,
                        max: 50,
                        sliderKey: const Key('gain'),
                        onChanged: enabled
                            ? (v) => update(() {
                                gain = v.round();
                                changes++;
                              })
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        SemanticsNode node(String label) =>
            tester.getSemantics(find.bySemanticsLabel(label));
        void act(String label, SemanticsAction action) => tester
            .binding
            .renderViews
            .single
            .owner!
            .semanticsOwner!
            .performAction(node(label).id, action);
        await show();
        for (final label in ['纯原声播放声音大小', '混声时原声比例']) {
          expect(find.bySemanticsLabel(label), findsOneWidget);
          expect(node(label).hasFlag(SemanticsFlag.isSlider), true);
          expect(
            node(label).getSemanticsData().hasAction(SemanticsAction.decrease),
            true,
          );
        }
        expect(node('纯原声播放声音大小').value, '90%');
        expect(node('混声时原声比例').value, '40%');
        act('纯原声播放声音大小', SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(volume, 80);
        expect(node('纯原声播放声音大小').value, '80%');
        act('混声时原声比例', SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(gain, 50);
        expect(node('混声时原声比例').value, '50%');
        final before = changes;
        enabled = false;
        await show();
        for (final label in ['纯原声播放声音大小', '混声时原声比例']) {
          final data = node(label).getSemanticsData();
          expect(data.hasAction(SemanticsAction.increase), false);
          expect(data.hasAction(SemanticsAction.decrease), false);
        }
        expect(changes, before);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        handle.dispose();
      }
    });
  }
}
