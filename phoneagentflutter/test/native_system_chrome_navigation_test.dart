import 'support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_page.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'app chrome follows each foreground page and restores $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
        // Force a distinct prior frame; SystemChrome caches styles across tests.
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.purple,
          ),
        );
        await tester.pump();
        styles.clear();
        await tester.pumpWidget(const ProviderScope(child: PhoneAgentApp()));
        await tester.pumpUntilUiSettled();
        void expectChrome({required bool darkPage}) {
          final android = platform == TargetPlatform.android;
          expect(styles, isNotEmpty);
          final style = styles.last;
          expect(style['statusBarColor'], Colors.transparent.toARGB32());
          expect(
            style['systemNavigationBarColor'],
            android ? Colors.transparent.toARGB32() : null,
          );
          expect(
            style['systemNavigationBarDividerColor'],
            android ? Colors.transparent.toARGB32() : null,
          );
          expect(
            style['statusBarIconBrightness'],
            darkPage ? 'Brightness.light' : 'Brightness.dark',
          );
          expect(
            style['statusBarBrightness'],
            darkPage ? 'Brightness.dark' : 'Brightness.light',
          );
          expect(
            style['systemNavigationBarIconBrightness'],
            android
                ? (darkPage ? 'Brightness.light' : 'Brightness.dark')
                : null,
          );
          expect(style['systemStatusBarContrastEnforced'], isFalse);
          expect(
            style['systemNavigationBarContrastEnforced'],
            android ? isFalse : isNull,
          );
        }

        expectChrome(darkPage: false);
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        const translation = TranslationCallView(
          phase: TranslationPhase.translating,
        );
        final pages = <Widget>[
          CallSessionPage(
            state: CallSessionState(
              target: CallSessionTarget(taskId: 'synthetic'),
            ),
            monitor: const CallMonitorView(),
            modelName: '合成通话模型',
            seconds: 0,
            onMonitor: () {},
            onHangup: () {},
            onSource: () {},
          ),
          TranslationCallPage(
            state: translation,
            target: '合成翻译对象',
            controls: TranslationCallControls(
              state: translation,
              onMute: () {},
              onSpeaker: () {},
              onPad: () {},
              onDigit: (_) {},
              onHangup: () {},
            ),
          ),
          const InvitePage(),
        ];
        for (final page in pages) {
          navigator.push(MaterialPageRoute<void>(builder: (_) => page));
          await tester.pumpUntilUiSettled();
          expectChrome(darkPage: true);
          navigator.pop();
          await tester.pumpUntilUiSettled();
          expectChrome(darkPage: false);
          expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpUntilUiSettled();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
