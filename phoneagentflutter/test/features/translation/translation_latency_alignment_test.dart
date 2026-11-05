import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_latency_pill.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final sample in [
      null,
      TranslationModelSample.reachable(140),
      TranslationModelSample.reachable(350),
      TranslationModelSample.reachable(700),
      const TranslationModelSample.unavailable(),
    ]) {
      testWidgets('status centered ${sample?.quality}/$scale', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(child: TranslationLatencyPill(sample: sample)),
            ),
          ),
        );
        final pill = find.byType(TranslationLatencyPill);
        final text = find.descendant(of: pill, matching: find.byType(Text));
        final box = find.descendant(of: pill, matching: find.byType(Container));
        expect(
          tester.getCenter(text).dx,
          closeTo(tester.getCenter(box).dx, .01),
        );
        expect(
          tester.getCenter(text).dy,
          closeTo(tester.getCenter(box).dy, .01),
        );
        if (scale == 1) expect(tester.getSize(box).height, 16);
        expect(tester.getSize(box).width, lessThan(200));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
