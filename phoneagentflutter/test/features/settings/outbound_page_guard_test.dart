import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'package:phone_agent/features/settings/presentation/controller/outbound_number_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/outbound_number_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform covered old write cannot dispatch or close cover', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      var saves = 0;
      final gate = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: platform),
          home: const Text('home'),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => OutboundNumberPage(
            state: const OutboundNumberState(draft: '2025550123'),
            onEdit: (_) {},
            onLoad: () async => false,
            onDelete: () async => false,
            onSave: () {
              saves++;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = tester
          .widget<NativeGradientAction>(find.byType(NativeGradientAction))
          .onPressed!;
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('cover')),
      );
      await tester.pumpAndSettle();
      save();
      await tester.pump();
      expect(saves, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      save();
      save();
      await tester.pump();
      expect(saves, 1);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('cover')),
      );
      await tester.pumpAndSettle();
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('cover'), findsOneWidget);
      expect(
        find.byType(OutboundNumberPage, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform disposed old write cannot dispatch', (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: OutboundNumberPage(
            state: const OutboundNumberState(),
            onEdit: (_) {},
            onLoad: () async => false,
            onDelete: () async => false,
            onSave: () async {
              saves++;
              return true;
            },
          ),
        ),
      );
      final save = tester
          .widget<NativeGradientAction>(find.byType(NativeGradientAction))
          .onPressed!;
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      save();
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.text('replacement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
