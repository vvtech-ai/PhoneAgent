import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/widgets/route_provider_scope.dart';

final _value = StateProvider<int>((_) => 0);

void main() {
  for (final same in [true, false]) {
    testWidgets(
      'route retains selected container without duplicate same=$same',
      (tester) async {
        final parent = ProviderContainer();
        final child = same
            ? parent
            : ProviderContainer(overrides: [_value.overrideWith((_) => 41)]);
        addTearDown(parent.dispose);
        if (!same) addTearDown(child.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: parent,
            child: MaterialApp(
              home: RouteProviderScope(
                container: child,
                child: Consumer(
                  builder: (_, ref, __) => Text('${ref.watch(_value)}'),
                ),
              ),
            ),
          ),
        );
        expect(
          find.byType(UncontrolledProviderScope),
          findsNWidgets(same ? 1 : 2),
        );
        expect(find.text(same ? '0' : '41'), findsOneWidget);
        child.read(_value.notifier).state = 42;
        await tester.pumpAndSettle();
        expect(find.text('42'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (!same) expect(parent.read(_value), 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(
          child.read(_value),
          42,
          reason: 'external container remains caller-owned',
        );
      },
    );
  }
}
