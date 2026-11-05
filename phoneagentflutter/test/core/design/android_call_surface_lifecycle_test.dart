import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/android_call_surface.dart';
import 'package:phone_agent/core/design/native_system_chrome.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';
import 'android_call_navigation_background_test.dart' show callPage;

bool isMode(MethodCall call) =>
    call.method.startsWith('SystemChrome.setEnabledSystemUI');

void main() {
  for (final translation in [false, true]) {
    testWidgets(
      'translation=$translation popup retains lease and other page/return releases it',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        final observer = PageRouteVisibilityObserver();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
          observer.dispose();
        });
        await tester.pumpWidget(
          PageRouteVisibilityScope(
            observer: observer,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: NativeSystemChrome.light,
              child: MaterialApp(
                theme: ThemeData(platform: TargetPlatform.android),
                navigatorObservers: [observer],
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (callContext) => Stack(
                            fit: StackFit.expand,
                            children: [
                              callPage(translation),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Column(
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          showModalBottomSheet<void>(
                                            context: callContext,
                                            backgroundColor: const Color(
                                              0xFF191D25,
                                            ),
                                            builder: (_) => const SizedBox(
                                              height: 160,
                                              child: Text('音源弹层'),
                                            ),
                                          ),
                                      child: const Text('打开弹层'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        callContext,
                                        MaterialPageRoute<void>(
                                          builder: (_) => const Scaffold(
                                            body: Center(child: Text('普通页面')),
                                          ),
                                        ),
                                      ),
                                      child: const Text('覆盖页面'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: const Text('进入通话'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls.where(isMode), isEmpty);
        await tester.tap(find.text('进入通话'));
        await tester.pumpAndSettle();
        expect(calls.where(isMode).last.arguments, 'SystemUiMode.edgeToEdge');
        expect(
          SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
          Brightness.light,
        );
        final beforeSheet = calls.where(isMode).length;
        await tester.tap(find.text('打开弹层'));
        await tester.pumpAndSettle();
        expect(find.text('音源弹层'), findsOneWidget);
        expect(
          SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
          Brightness.light,
        );
        expect(calls.where(isMode).length, beforeSheet);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(calls.where(isMode).length, beforeSheet);
        await tester.tap(find.text('覆盖页面'));
        await tester.pumpAndSettle();
        expect(find.text('普通页面'), findsOneWidget);
        expect(
          calls.where(isMode).last.method,
          'SystemChrome.setEnabledSystemUIOverlays',
        );
        expect(
          calls.where(isMode).last.arguments,
          containsAll(['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
        );
        expect(
          SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
          Brightness.dark,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(calls.where(isMode).last.arguments, 'SystemUiMode.edgeToEdge');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('进入通话'), findsOneWidget);
        expect(
          calls.where(isMode).last.method,
          'SystemChrome.setEnabledSystemUIOverlays',
        );
        expect(
          SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
          Brightness.dark,
        );
      },
    );
  }

  testWidgets(
    'old release cannot override a new call while platform reply is pending',
    (tester) async {
      final calls = <MethodCall>[], first = Completer<void>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          if (isMode(call) && calls.where(isMode).length == 1) {
            await first.future;
          }
          return null;
        },
      );
      addTearDown(() async {
        if (!first.isCompleted) first.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      Widget render(String key) => MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: AndroidCallSurface(
          key: ValueKey(key),
          backgroundColor: Colors.black,
          child: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(render('old'));
      await tester.pump();
      expect(calls.where(isMode), hasLength(1));
      await tester.pumpWidget(render('new'));
      await tester.pump();
      first.complete();
      await tester.pumpAndSettle();
      expect(calls.where(isMode).last.arguments, 'SystemUiMode.edgeToEdge');
      expect(
        calls.where(
          (c) => c.method == 'SystemChrome.setEnabledSystemUIOverlays',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        calls.where(isMode).last.method,
        'SystemChrome.setEnabledSystemUIOverlays',
      );
    },
  );
}
