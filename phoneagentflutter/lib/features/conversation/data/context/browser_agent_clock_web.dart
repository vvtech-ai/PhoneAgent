import 'dart:js_interop';
import '../../domain/context/agent_clock.dart';

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String get timeZone;
}

AgentClockSnapshot readBrowserAgentClock() {
  final fallback = AgentClockSnapshot.localNow();
  try {
    return AgentClockSnapshot(
      epochMillis: fallback.epochMillis,
      offsetSeconds: fallback.offsetSeconds,
      timezone: _DateTimeFormat().resolvedOptions().timeZone,
    );
  } catch (_) {
    return fallback;
  }
}
