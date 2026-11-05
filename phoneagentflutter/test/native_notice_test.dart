import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';

void main() {
  testWidgets('all points stars use iOS yellow while text stays dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNativeNotice(context, '初始赠送 ✦100，今日赠送 ✦20'),
            child: const Text('显示'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('显示'));
    await tester.pump();
    final text = tester.widget<Text>(find.text('初始赠送 ✦100，今日赠送 ✦20'));
    expect(text.style!.color, const Color(0xFF1A1A1A));
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.where((s) => s.text == '✦'), hasLength(2));
    for (final span in spans) {
      expect(
        span.style?.color,
        span.text == '✦' ? const Color(0xFFFFC400) : null,
      );
    }
    dismissNativeNotice();
    await tester.pump();
  });

  testWidgets('notice does not intercept navigation and expires', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                onPressed: () {
                  presses++;
                  showNativeNotice(context, '合成结果');
                },
                child: const Text('导航操作'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('导航操作'));
    await tester.pump();
    expect(find.text('合成结果'), findsOneWidget);
    await tester.tap(find.text('导航操作'));
    await tester.pump();
    expect(presses, 2);
    expect(find.text('合成结果'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump(const Duration(milliseconds: 2160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    await tester.pump();
    // The second click enqueues another full notice instead of replacing it.
    expect(find.text('合成结果'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    await tester.pump();
    expect(find.text('合成结果'), findsNothing);
  });

  testWidgets('native style fades around custom hold duration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNativeNotice(
              context,
              '原生样式',
              duration: const Duration(seconds: 2),
            ),
            child: const Text('显示'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('显示'));
    await tester.pump();
    final surface = find.byKey(const ValueKey('nativeNoticeSurface'));
    final box =
        tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
    expect(box.color, const Color(0xFAFFFFFF));
    expect(box.border, Border.all(color: const Color(0xFFD1D1D1)));
    expect(box.borderRadius, BorderRadius.circular(10));
    expect(box.boxShadow!.single.offset, const Offset(0, 3));
    final text = tester.widget<Text>(find.text('原生样式'));
    expect(text.style!.fontSize, 15);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.color, const Color(0xFF1A1A1A));
    final fade = find
        .ancestor(of: surface, matching: find.byType(FadeTransition))
        .first;
    double opacity() => tester.widget<FadeTransition>(fade).opacity.value;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), closeTo(.5, .01));
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), closeTo(.5, .01));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(surface, findsNothing);
  });

  testWidgets('brand and long scaled text fit a small screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showNativeNotice(context, '这是一条用于验证小屏幕和大字体自动换行的完整提示'),
            child: const Text('显示'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('显示'));
    await tester.pump();
    final brand = find.byKey(const ValueKey('nativeNoticeBrand'));
    expect(tester.getSize(brand), const Size(22, 22));
    final image = tester.widget<Image>(brand);
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/auth_brand_logo.png',
    );
    final surface = tester.getRect(
      find.byKey(const ValueKey('nativeNoticeSurface')),
    );
    expect(surface.left, greaterThanOrEqualTo(32));
    expect(surface.right, lessThanOrEqualTo(288));
    expect(tester.takeException(), isNull);
    dismissNativeNotice();
    await tester.pump();
    expect(brand, findsNothing);
  });

  testWidgets('removing account overlay cancels pending notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showNativeNotice(context, '旧账号结果'),
              child: const Text('显示'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('显示'));
    await tester.pump();
    expect(find.text('旧账号结果'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
