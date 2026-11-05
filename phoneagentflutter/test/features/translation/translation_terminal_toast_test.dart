import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_call_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_route.dart';

class _Call extends StateNotifier<TranslationCallView>
    implements TranslationCallController {
  _Call() : super(const TranslationCallView());
  bool failHangup = false;
  void emit(TranslationCallView value) => state = value;
  @override
  TranslationCallView get snapshot => state;
  @override
  Future<void> start() async {}
  @override
  Future<void> mute() async {}
  @override
  Future<void> speaker() async {}
  @override
  void dialPad() {}
  @override
  Future<void> digit(String digit) async {}
  @override
  Future<void> hangup() async {
    if (failHangup) throw StateError('synthetic hangup failure');
  }
}

void main() {
  tearDown(dismissNativeNotice);
  for (final failed in [false, true]) {
    testWidgets(
      'confirmed settlement survives terminal pop with failed=$failed',
      (tester) async {
        late _Call call;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    call = _Call();
                    Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TranslationSessionRoute(
                          target: 'test',
                          createController: () => call,
                        ),
                      ),
                    );
                  },
                  child: const Text('dial'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('dial'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        const bill = '本次扣除 ✦15 积分，剩余 ✦85 积分';
        final terminal = TranslationCallView(
          phase: failed ? TranslationPhase.failed : TranslationPhase.ended,
          error: failed ? '对方正在通话中' : '',
          settlementNotice: bill,
        );
        call.emit(terminal);
        call.emit(terminal.copy());
        await tester.pumpAndSettle();
        expect(find.byType(TranslationSessionRoute), findsNothing);
        if (failed) {
          expect(find.text('对方正在通话中'), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }
        expect(find.text(bill), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'call operation failure is transient including hangup on $platform',
      (tester) async {
        final call = _Call();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: TranslationSessionRoute(
              target: 'test',
              createController: () => call,
            ),
          ),
        );
        await tester.pumpAndSettle();
        const error = '操作未成功，原状态未改变，请重试';
        call.emit(
          const TranslationCallView(
            phase: TranslationPhase.translating,
            error: error,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('nativeNoticeSurface')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text(error), findsNothing);
        call.failHangup = true;
        await tester.tap(find.bySemanticsLabel('挂断'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('nativeNoticeSurface')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    for (final message in ['对方正在通话中', '通话已结束，但结算结果暂不可用，请稍后查看积分流水']) {
      testWidgets(
        'terminal Toast survives pop once and can repeat on next call $platform: $message',
        (tester) async {
          late _Call call;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      call = _Call();
                      Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TranslationSessionRoute(
                            target: 'test',
                            createController: () => call,
                          ),
                        ),
                      );
                    },
                    child: const Text('dial'),
                  ),
                ),
              ),
            ),
          );
          for (var attempt = 0; attempt < 2; attempt++) {
            await tester.tap(find.text('dial'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            final failure = TranslationCallView(
              phase: TranslationPhase.failed,
              error: message,
            );
            call.emit(failure);
            call.emit(
              failure.copy(),
            ); // A late duplicate terminal must not queue another notice.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
            expect(find.byType(TranslationSessionRoute), findsNothing);
            expect(find.text('dial'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('nativeNoticeSurface')),
              findsOneWidget,
            );
            expect(find.text(message), findsOneWidget);
            expect(find.text('通话未接通，请稍后重试'), findsNothing);
            expect(find.textContaining('本次扣除'), findsNothing);
            await tester.pump(const Duration(seconds: 4));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('nativeNoticeSurface')),
              findsNothing,
            );
            expect(find.text(message), findsNothing);
          }
          await tester.tap(find.text('dial'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          call.emit(const TranslationCallView(phase: TranslationPhase.ended));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('nativeNoticeSurface')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
