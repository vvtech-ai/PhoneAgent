import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';

const _empty = '音色列表暂未加载成功，请稍后重试。';
const _catalog = CallVoiceCatalog('Andre', 'AI', [
  CallVoice('Andre', 'Andre', '合成样音', true),
]);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform catalog loading empty failure retry and cache', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var retries = 0;
      Future<void> show(CallModelState state) async {
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
              body: CallVoicesPage(
                state: state,
                onBack: () {},
                onRetry: () => retries++,
                onSelect: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(
        const CallModelState(voiceProvider: 'DOUBAO', voiceLoading: true),
      );
      expect(find.text('加载中...'), findsOneWidget);
      expect(find.text(_empty), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(retries, 0);
      await show(const CallModelState(voiceProvider: 'DOUBAO'));
      expect(find.text('加载中...'), findsNothing);
      expect(find.text(_empty), findsOneWidget);
      await tester.ensureVisible(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试'));
      expect(retries, 1);
      await show(
        const CallModelState(
          voiceProvider: 'DOUBAO',
          voices: CallVoiceCatalog('', 'AI', []),
        ),
      );
      expect(find.text(_empty), findsOneWidget);
      expect(find.text('暂无系统音色'), findsNothing);
      await show(
        const CallModelState(
          voiceProvider: 'DOUBAO',
          voiceError: '合成读取失败',
          voices: _catalog,
        ),
      );
      expect(find.text('合成读取失败'), findsOneWidget);
      expect(find.text(_empty), findsNothing);
      expect(
        tester.widget<Text>(find.text('合成读取失败')).style!.color,
        const Color(0xFFE14D46),
      );
      expect(find.text('Andre'), findsOneWidget);
      await tester.ensureVisible(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试'));
      expect(retries, 2);
      await show(
        const CallModelState(
          voiceProvider: 'DOUBAO',
          voiceLoading: true,
          voices: _catalog,
        ),
      );
      expect(find.text('Andre'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('加载中...'), findsNothing);
      expect(find.text(_empty), findsNothing);
      expect(retries, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
