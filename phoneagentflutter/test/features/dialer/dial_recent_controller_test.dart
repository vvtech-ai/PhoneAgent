import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_recent_controller.dart';

class Source implements DialRecentCallSource {
  Source(this.read);
  final Future<DialRecentSnapshot> Function() read;
  int calls = 0;
  @override
  Future<DialRecentSnapshot> load() {
    calls++;
    return read();
  }
}

class ObservableSource extends Source implements ObservableDialRecentSource {
  ObservableSource(super.read);
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => events.stream;
}

const systemRecord = DialRecentCall(
  id: 'system',
  phone: '+12025550101',
  startedAtMillis: 1,
  source: DialRecentSource.system,
);
const appRecord = DialRecentCall(
  id: 'app',
  phone: '+12025550102',
  startedAtMillis: 2,
  source: DialRecentSource.app,
  kind: DialRecentKind.translation,
);

void main() {
  test(
    'local change invalidates a pending old read and coalesces a reload',
    () async {
      final gate = Completer<DialRecentSnapshot>();
      var first = true;
      final app = ObservableSource(() {
        if (first) {
          first = false;
          return gate.future;
        }
        return Future.value(const DialRecentSnapshot(DialRecentAccess.ready));
      });
      final c = DialRecentController(
        Source(
          () async => const DialRecentSnapshot(DialRecentAccess.unsupported),
        ),
        app,
      );
      final seen = <int>[];
      c.addListener((state) => seen.add(state.records.length));
      final pending = c.load();
      app.events.add(null);
      app.events.add(null);
      await Future<void>.delayed(Duration.zero);
      gate.complete(
        const DialRecentSnapshot(DialRecentAccess.ready, [appRecord]),
      );
      await pending;
      expect(c.state.records, isEmpty);
      expect(seen, everyElement(0));
      expect(app.calls, 2);
      c.dispose();
      await app.events.close();
    },
  );
  test(
    'new local event refreshes loaded rows and disposal cancels events',
    () async {
      var rows = <DialRecentCall>[];
      final app = ObservableSource(
        () async => DialRecentSnapshot(DialRecentAccess.ready, rows),
      );
      final c = DialRecentController(
        Source(
          () async => const DialRecentSnapshot(DialRecentAccess.unsupported),
        ),
        app,
      );
      await c.load();
      rows = [appRecord];
      app.events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.records, [appRecord]);
      c.dispose();
      final reads = app.calls;
      app.events.add(null);
      await app.events.close();
      expect(app.calls, reads);
    },
  );
  test(
    'one source failure leaves the other visible and retry can recover',
    () async {
      var fail = true;
      final system = Source(() async {
        if (fail) throw StateError('synthetic read failure');
        return const DialRecentSnapshot(DialRecentAccess.ready, [systemRecord]);
      });
      final app = Source(
        () async =>
            const DialRecentSnapshot(DialRecentAccess.ready, [appRecord]),
      );
      final controller = DialRecentController(system, app);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.system.access, DialRecentAccess.failed);
      expect(controller.state.records, [appRecord]);
      fail = false;
      await controller.load();
      expect(controller.state.records, [appRecord, systemRecord]);
    },
  );
  test(
    'parallel single-flight, clear stale records, discard denied payload',
    () async {
      Completer<DialRecentSnapshot>? pending;
      final system = Source(
        () async => pending == null
            ? const DialRecentSnapshot(DialRecentAccess.ready, [systemRecord])
            : pending.future,
      );
      final app = Source(
        () async => const DialRecentSnapshot(DialRecentAccess.notConnected),
      );
      final controller = DialRecentController(system, app);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.records, [systemRecord]);
      pending = Completer();
      final read = controller.load();
      expect(controller.state.records, isEmpty);
      await controller.load();
      expect(system.calls, 2);
      pending.complete(
        const DialRecentSnapshot(DialRecentAccess.denied, [systemRecord]),
      );
      await read;
      expect(controller.state.records, isEmpty);
      expect(controller.state.system.records, isEmpty);
      expect(controller.state.loading, isFalse);
    },
  );
  test(
    'sources cannot smuggle another source identity; disposal ignores late data',
    () async {
      final system = Source(
        () async =>
            const DialRecentSnapshot(DialRecentAccess.ready, [appRecord]),
      );
      final gate = Completer<DialRecentSnapshot>();
      final controller = DialRecentController(
        system,
        Source(() => gate.future),
      );
      var changes = 0;
      controller.addListener((_) => changes++);
      final read = controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.system.records, isEmpty);
      controller.dispose();
      final before = changes;
      gate.complete(
        const DialRecentSnapshot(DialRecentAccess.ready, [appRecord]),
      );
      await read;
      expect(changes, before);
    },
  );
}
