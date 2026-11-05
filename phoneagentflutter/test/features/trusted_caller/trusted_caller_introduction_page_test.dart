import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_caller_introduction_page.dart';

void main() {
  testWidgets('vertical touch keeps scrolling while example image rotates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: TrustedCallerIntroductionPage(
            onStart: () => starts++,
            onExit: () {},
          ),
        ),
      ),
    );
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.pixels, 0);
    final touch = await tester.startGesture(const Offset(160, 300));
    await touch.moveBy(const Offset(0, -100));
    await tester.pump(const Duration(seconds: 2));
    await touch.moveBy(const Offset(0, -200));
    await touch.up();
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(100));
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, -1000),
      800,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trusted-introduction-start')));
    expect(starts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'short screen at $scale keeps explanation and start reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var starts = 0, exits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale),
              ),
              child: TrustedCallerIntroductionPage(
                onStart: () => starts++,
                onExit: () => exits++,
              ),
            ),
          ),
        );
        expect(find.text('可信通信组件'), findsOneWidget);
        expect(find.text('来电归属地升级版'), findsOneWidget);
        expect(starts, 0);
        await tester.ensureVisible(
          find.byKey(const Key('trusted-introduction-start')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('trusted-introduction-start')));
        expect(starts, 1);
        expect(exits, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('three images rotate every two seconds and stop offscreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedCallerIntroductionPage(onStart: () {}, onExit: () {}),
      ),
    );
    expect(
      find.byKey(const ValueKey('trusted-introduction-image-1')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byKey(const ValueKey('trusted-introduction-image-2')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byKey(const ValueKey('trusted-introduction-image-3')),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const ValueKey('trusted-introduction-image-3')),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byKey(const ValueKey('trusted-introduction-image-1')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion and assistive navigation keep a stable image', (
    tester,
  ) async {
    for (final accessible in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: !accessible,
              accessibleNavigation: accessible,
            ),
            child: TrustedCallerIntroductionPage(onStart: () {}, onExit: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(
        find.byKey(const ValueKey('trusted-introduction-image-1')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('edge exit and busy start never imply successful authorization', (
    tester,
  ) async {
    var starts = 0, exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedCallerIntroductionPage(
          onStart: () => starts++,
          onExit: () => exits++,
          busy: true,
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const Key('trusted-introduction-start')),
    );
    await tester.tap(find.byKey(const Key('trusted-introduction-start')));
    expect(starts, 0);
    await tester.dragFrom(const Offset(2, 200), const Offset(150, 0));
    expect(exits, 1);
    expect(starts, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
