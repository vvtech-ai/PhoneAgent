import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_controls.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_icons.dart';

// Independent native reference: aiassistant-app 8f235920 ic_agent_call_*.xml.
const _nativePaths = {
  'listen':
      '<path d="M6,8.5a6.5,6.5 0,1 1,13 0c0,6 -6,6 -6,10a3.5,3.5 0,1 1,-7 0"/><path d="M15,8.5a2.5,2.5 0,0 0,-5 0v1a2,2 0,1 1,0 4"/>',
  'listen_off':
      '<path d="M6,8.5a6.5,6.5 0,1 1,13 0c0,6 -6,6 -6,10a3.5,3.5 0,1 1,-7 0"/><path d="M15,8.5a2.5,2.5 0,0 0,-5 0v1a2,2 0,1 1,0 4"/><path d="M4.5,19.5L19.5,4.5"/>',
  'hangup':
      '<path fill="white" stroke="none" d="M12,9c-1.6,0 -3.15,0.25 -4.6,0.72v3.1c0,0.4 -0.23,0.74 -0.56,0.9 -0.98,0.49 -1.87,1.12 -2.66,1.85 -0.18,0.18 -0.43,0.28 -0.7,0.28s-0.52,-0.11 -0.7,-0.29L0.29,13.08C0.11,12.9 0,12.65 0,12.37s0.11,-0.53 0.29,-0.71C3.34,8.78 7.5,7 12,7s8.66,1.78 11.71,4.67c0.18,0.18 0.29,0.43 0.29,0.71s-0.11,0.53 -0.29,0.71l-2.48,2.48c-0.18,0.18 -0.43,0.29 -0.7,0.29s-0.52,-0.11 -0.7,-0.28c-0.79,-0.73 -1.68,-1.36 -2.66,-1.85 -0.33,-0.16 -0.56,-0.51 -0.56,-0.9v-3.1C15.15,9.25 13.6,9 12,9z"/>',
  'earpiece':
      '<path d="M7,2h10a2,2 0,0 1,2 2v16a2,2 0,0 1,-2 2H7a2,2 0,0 1,-2 -2V4a2,2 0,0 1,2 -2z"/><path d="M12,18h0.01"/>',
  'speaker':
      '<path d="M11,4.702a0.705,0.705 0,0 0,-1.203 -0.498L6.413,7.587A1.4,1.4 0,0 1,5.416 8H3a1,1 0,0 0,-1 1v6a1,1 0,0 0,1 1h2.416a1.4,1.4 0,0 1,0.997 0.413l3.383,3.384A0.705,0.705 0,0 0,11 19.298z"/><path d="M16,9a5,5 0,0 1,0 6"/><path d="M19.364,18.364a9,9 0,0 0,0 -12.728"/>',
  'bluetooth': '<path d="M7,7L17,17L12,22V2L17,7L7,17"/>',
};

void main() {
  for (final entry in _nativePaths.entries) {
    testWidgets(
      '${entry.key} renders native vector at 24 pixels without cropping',
      (tester) async {
        final paths = switch (entry.key) {
          'listen' || 'listen_off' => CallIcons.listen,
          'hangup' => CallIcons.hangup,
          'earpiece' => CallIcons.earpiece,
          'speaker' => CallIcons.speaker,
          _ => CallIcons.bluetooth,
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  RepaintBoundary(
                    key: const ValueKey('actual'),
                    child: CallIcons.icon(
                      paths,
                      off: entry.key == 'listen_off',
                    ),
                  ),
                  RepaintBoundary(
                    key: const ValueKey('native'),
                    child: SvgPicture.string(
                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${entry.value}</svg>',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('actual'))),
          const Size(24, 24),
        );
        Future<List<int>> pixels(String key) async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(ValueKey(key)),
          );
          final image = await boundary.toImage(pixelRatio: 3);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return data!.buffer.asUint8List();
        }

        final actual = await tester.runAsync(() => pixels('actual'));
        final native = await tester.runAsync(() => pixels('native'));
        expect(
          actual,
          orderedEquals(native!),
          reason: 'Native outline/fill and full viewport must match at 3x',
        );
      },
    );
  }

  testWidgets(
    'production controls keep native 52 button and 24 centered icon',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: CallControls(
              call: CallSessionState(
                target: CallSessionTarget(taskId: 'task', callId: 'call'),
              ),
              monitor: const CallMonitorView(),
              onMonitor: () {},
              onHangup: () {},
              onSource: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in ['call-开始监听', 'call-挂断', 'call-音源，听筒']) {
        final button = find.byKey(ValueKey(key));
        final icon = find.descendant(
          of: button,
          matching: find.byType(SvgPicture),
        );
        expect(tester.getSize(button), const Size(52, 52));
        expect(tester.getSize(icon), const Size(24, 24));
        expect(tester.getCenter(icon), tester.getCenter(button));
      }
    },
  );
}
