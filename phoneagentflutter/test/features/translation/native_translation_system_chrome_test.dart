import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('dark translation chrome is local and restores $platform', (
      tester,
    ) async {
      final styles = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
            styles.add(Map<Object?, Object?>.from(call.arguments as Map));
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: platform),
          builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('合成宿主页'))),
        ),
      );
      const state = TranslationCallView(phase: TranslationPhase.translating);
      for (var repeat = 0; repeat < 2; repeat++) {
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => TranslationCallPage(
              state: state,
              target: '合成翻译对象',
              controls: TranslationCallControls(
                state: state,
                onMute: () {},
                onSpeaker: () {},
                onPad: () {},
                onDigit: (_) {},
                onHangup: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(styles.last['statusBarIconBrightness'], 'Brightness.light');
        expect(styles.last['statusBarBrightness'], 'Brightness.dark');
        expect(styles.last['statusBarColor'], Colors.transparent.toARGB32());
        expect(
          styles.last['systemNavigationBarColor'],
          Colors.transparent.toARGB32(),
        );
        expect(
          styles.last['systemNavigationBarIconBrightness'],
          'Brightness.light',
        );
        expect(styles.last['systemNavigationBarContrastEnforced'], isFalse);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('合成宿主页'), findsOneWidget);
        expect(styles.last['statusBarIconBrightness'], 'Brightness.dark');
        expect(styles.last['statusBarBrightness'], 'Brightness.light');
        expect(
          styles.last['systemNavigationBarColor'],
          Colors.white.toARGB32(),
        );
        expect(
          styles.last['systemNavigationBarIconBrightness'],
          'Brightness.dark',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
