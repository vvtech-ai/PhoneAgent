@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:phone_agent/features/conversation/data/context/browser_agent_clock_web.dart';

void main() {
  test(
    'actual browser Intl timezone and offset form a valid current instant',
    () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      final clock = readBrowserAgentClock();
      expect(clock.epochMillis, greaterThanOrEqualTo(before));
      expect(clock.timezone, matches(r'^[A-Za-z]'));
      final decoded = DateTime.parse(
        clock.toContext()['isoDateTime'] as String,
      );
      expect(decoded.millisecondsSinceEpoch, clock.epochMillis);
      expect(clock.offsetSeconds, DateTime.now().timeZoneOffset.inSeconds);
    },
  );
}
