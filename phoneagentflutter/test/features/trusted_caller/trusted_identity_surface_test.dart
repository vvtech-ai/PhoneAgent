import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/trusted_incoming_identity_providers.dart';
import 'package:phone_agent/features/trusted_caller/presentation/controller/trusted_incoming_identity_controller.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_identity_surface_port.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/presentation/controller/trusted_identity_surface_controller.dart';

const owner = TrustedCallerOwner('synthetic', '12345678901', 1);
TrustedIncomingIdentity identity(String id) => TrustedIncomingIdentity(
  owner: owner,
  eventId: id,
  name: '身份$id',
  verification: TrustedIdentityVerification.pending,
);

class Surface implements TrustedIdentitySurfacePort {
  final controller = StreamController<TrustedIdentitySurfaceEvent>.broadcast();
  final calls = <TrustedIncomingIdentity?>[];
  final pending = <Completer<TrustedIdentitySurfaceResult>>[];
  TrustedIdentitySurfaceResult result = TrustedIdentitySurfaceResult.overlay;
  bool wait = false;
  @override
  Stream<TrustedIdentitySurfaceEvent> get events => controller.stream;
  @override
  Future<TrustedIdentitySurfaceResult> synchronize(
    TrustedIncomingIdentity? value,
  ) {
    calls.add(value);
    if (!wait) return Future.value(result);
    final completer = Completer<TrustedIdentitySurfaceResult>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> dispose() => controller.close();
}

void main() {
  late Surface port;
  late TrustedIdentitySurfaceController controller;
  late List<String> dismissed, diagnostics;
  setUp(() {
    port = Surface();
    dismissed = [];
    diagnostics = [];
    controller = TrustedIdentitySurfaceController(
      port: port,
      onDismiss: dismissed.add,
      onDiagnostic: diagnostics.add,
    );
  });
  tearDown(() async {
    controller.dispose();
    await port.dispose();
  });
  testWidgets('SDK overlay suppresses ordinary route and stale dismiss', (
    tester,
  ) async {
    controller.update(identity('A'));
    await tester.pump();
    expect(controller.state, isNull);
    controller.update(identity('B'));
    await tester.pump();
    port.controller.add(const TrustedIdentitySurfaceEvent('dismissed', 'A'));
    port.controller.add(const TrustedIdentitySurfaceEvent('presented', 'A'));
    await tester.pump();
    expect(dismissed, isEmpty);
    expect(diagnostics, isEmpty);
    port.controller.add(const TrustedIdentitySurfaceEvent('presented', 'B'));
    port.controller.add(const TrustedIdentitySurfaceEvent('dismissed', 'B'));
    await tester.pump();
    expect(diagnostics, ['IOS_PRESENTED']);
    expect(dismissed, ['B']);
  });
  testWidgets('ordinary fallback supplies current identity and clear', (
    tester,
  ) async {
    port.result = TrustedIdentitySurfaceResult.fallback;
    controller.update(identity('A'));
    await tester.pump();
    expect(controller.state?.eventId, 'A');
    controller.update(identity('B'));
    await tester.pump();
    expect(controller.state?.eventId, 'B');
    expect(dismissed, isEmpty);
    controller.update(null);
    expect(controller.state, isNull);
    await tester.pump();
    expect(port.calls.last, isNull);
  });
  testWidgets('inflight old response cannot restore cleared identity', (
    tester,
  ) async {
    port.wait = true;
    controller.update(identity('A'));
    controller.update(identity('B'));
    controller.update(null);
    expect(port.calls.length, 1);
    port.pending.first.complete(TrustedIdentitySurfaceResult.fallback);
    await tester.pump();
    expect(port.calls.length, 2);
    expect(port.calls.last, isNull);
    port.pending.last.complete(TrustedIdentitySurfaceResult.fallback);
    await tester.pump();
    expect(controller.state, isNull);
  });
  testWidgets('deferred native transition retries without hidden route', (
    tester,
  ) async {
    port.result = TrustedIdentitySurfaceResult.deferred;
    controller.update(identity('A'));
    await tester.pump();
    expect(controller.state, isNull);
    port.result = TrustedIdentitySurfaceResult.overlay;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(port.calls.length, 2);
    expect(diagnostics, contains('IOS_PRESENTATION_DEFERRED'));
  });
  testWidgets(
    'paused root Flutter still forwards data and native resume retries',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      controller.update(identity('A'));
      // No frame is pumped: platform delivery must start synchronously from events.
      expect(port.calls.single?.eventId, 'A');
      await tester.pump();
      controller.update(identity('B'));
      expect(port.calls.last?.eventId, 'B');
      await tester.pump();
      port.controller.add(const TrustedIdentitySurfaceEvent('retry', ''));
      await tester.pump();
      expect(port.calls.length, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
  testWidgets('late native completion after disposal cannot restore identity', (
    tester,
  ) async {
    port.wait = true;
    controller.update(identity('A'));
    controller.dispose();
    port.pending.single.complete(TrustedIdentitySurfaceResult.fallback);
    await tester.pump();
    expect(dismissed, isEmpty);
    expect(diagnostics, isEmpty);
    // StateNotifier disposal is idempotent only through the owner.
    controller = TrustedIdentitySurfaceController(
      port: port,
      onDismiss: dismissed.add,
      onDiagnostic: diagnostics.add,
    );
  });
  test(
    'provider forwards events while root Flutter is paused without rebuilding',
    () async {
      final events = StreamController<TrustedIncomingIdentity?>(sync: true);
      final container = ProviderContainer(
        overrides: [
          trustedIdentitySurfacePortProvider.overrideWithValue(port),
          trustedIncomingIdentityControllerProvider.overrideWith(
            (ref) => TrustedIncomingIdentityController(
              owner: owner,
              events: events.stream,
              isCurrent: (_) => true,
            ),
          ),
        ],
      );
      final subscription = container.listen(
        trustedIdentitySurfaceControllerProvider,
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      events.add(identity('A'));
      expect(port.calls.last?.eventId, 'A');
      await Future<void>.delayed(Duration.zero);
      events.add(identity('B'));
      expect(port.calls.last?.eventId, 'B');
      await Future<void>.delayed(Duration.zero);
      events.add(null);
      expect(port.calls.last, isNull);
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      subscription.close();
      container.dispose();
      final closed = events.close();
      await Future<void>.delayed(Duration.zero);
      await closed;
    },
  );
}
