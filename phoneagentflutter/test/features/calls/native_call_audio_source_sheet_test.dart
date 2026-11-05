import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/widgets/native_call_audio_source_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'source rows preserve selection and fit short large text $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final handle = tester.ensureSemantics();
        CallAudioSource? chosen;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: NativeCallAudioSourceSheet(
                monitor: const CallMonitorView(source: CallAudioSource.speaker),
                onSelect: (value) => chosen = value,
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('蓝牙'), findsNothing);
        expect(find.text('取消'), findsOneWidget);
        final row = find.byKey(const ValueKey('source-speaker'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final semantics = tester.getSemantics(find.bySemanticsLabel('扬声器'));
        expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
        expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
        await tester.tap(row);
        expect(chosen, CallAudioSource.speaker);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  }
}
