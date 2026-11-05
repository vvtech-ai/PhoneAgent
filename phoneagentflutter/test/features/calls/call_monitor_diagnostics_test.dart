import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/calls/data/call_monitor_stream.dart';
import 'package:phone_agent/features/calls/data/preview_call_monitor.dart';
import '../../support/call_monitor_fixture.dart';

void main() {
  for (final invalid in [true, false]) {
    test(
      'monitor diagnostics invalid=$invalid records safe boundary reason',
      () async {
        final events = <DiagnosticEvent>[];
        final socket = PreviewMonitorSocket();
        final output = TestMonitorOutput();
        final monitor = CallMonitorStream(
          apiBase: Uri.parse('https://synthetic.invalid/'),
          connect: (_) async => socket,
          output: output,
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.callMonitor,
          ),
        );
        final subscription = monitor.disconnected.listen((_) {});
        await monitor.start(monitorTicket(), 'earpiece');
        if (invalid) {
          socket.add(Uint8List(1));
        } else {
          socket.fail();
        }
        await Future<void>.delayed(Duration.zero);
        expect(
          events.any(
            (event) =>
                event.media?.reason ==
                (invalid
                    ? DiagnosticMediaReason.invalidPcm
                    : DiagnosticMediaReason.transportError),
          ),
          isTrue,
        );
        await monitor.close();
        await subscription.cancel();
        final encoded = jsonEncode(
          events.map((event) => event.toJson()).toList(),
        );
        expect(encoded, isNot(contains('synthetic')));
        expect(encoded, isNot(contains('ticket')));
        expect(
          events.every(
            (event) =>
                event.media?.component == DiagnosticMediaComponent.callMonitor,
          ),
          isTrue,
        );
      },
    );
  }
}
