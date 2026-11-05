import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/presentation/controller/trusted_incoming_identity_controller.dart';

void main() {
  const owner = TrustedCallerOwner('synthetic', 'synthetic-phone', 1);
  test(
    'explicit new presentation can reopen; late revision and close cannot',
    () async {
      final events = StreamController<TrustedIncomingIdentity?>();
      final controller = TrustedIncomingIdentityController(
        owner: owner,
        events: events.stream,
        isCurrent: (_) => true,
      );
      TrustedIncomingIdentity value(int revision) => TrustedIncomingIdentity(
        owner: owner,
        eventId: 'same',
        verification: TrustedIdentityVerification.verified,
        presentationRevision: revision,
      );
      events.add(value(0));
      await Future<void>.delayed(Duration.zero);
      controller.dismiss('same');
      events.add(value(1));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state?.presentationId, 'same:1');
      controller.dismiss('same');
      expect(controller.state?.presentationId, 'same:1');
      controller.dismiss('same:1');
      events.add(value(0));
      events.add(value(1));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNull);
      events.add(value(2));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state?.presentationId, 'same:2');
      controller.dispose();
      await events.close();
    },
  );
  TrustedIncomingIdentity identity(
    String id,
    TrustedIdentityVerification verification, {
    TrustedCallerOwner captured = owner,
  }) => TrustedIncomingIdentity(
    owner: captured,
    eventId: id,
    verification: verification,
  );
  test(
    'dismissed preview cannot reopen on verification; new event can',
    () async {
      final events = StreamController<TrustedIncomingIdentity?>();
      final controller = TrustedIncomingIdentityController(
        owner: owner,
        events: events.stream,
        isCurrent: (_) => true,
      );
      events.add(identity('first', TrustedIdentityVerification.pending));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state?.verification,
        TrustedIdentityVerification.pending,
      );
      controller.dismiss('first');
      events.add(identity('first', TrustedIdentityVerification.verified));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNull);
      events.add(identity('second', TrustedIdentityVerification.verified));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state?.eventId, 'second');
      controller.dismiss('first');
      expect(controller.state?.eventId, 'second');
      events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNull);
      controller.dispose();
      await events.close();
    },
  );
  test('changed current owner rejects late verified identity', () async {
    var current = owner;
    final events = StreamController<TrustedIncomingIdentity?>();
    final controller = TrustedIncomingIdentityController(
      owner: owner,
      events: events.stream,
      isCurrent: (captured) => captured.matches(current),
    );
    events.add(identity('first', TrustedIdentityVerification.pending));
    await Future<void>.delayed(Duration.zero);
    current = const TrustedCallerOwner('other', 'other-phone', 2);
    events.add(identity('first', TrustedIdentityVerification.verified));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isNull);
    current = owner;
    events.add(
      identity('restored-old-generation', TrustedIdentityVerification.verified),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isNull);
    controller.dispose();
    await events.close();
  });
  test(
    'foreign report and stream failure clear old verified certificate',
    () async {
      final events = StreamController<TrustedIncomingIdentity?>();
      final controller = TrustedIncomingIdentityController(
        owner: owner,
        events: events.stream,
        isCurrent: (_) => true,
      );
      events.add(identity('first', TrustedIdentityVerification.verified));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state?.hasCertificate, true);
      events.add(
        identity(
          'foreign',
          TrustedIdentityVerification.verified,
          captured: const TrustedCallerOwner('other', 'other-phone', 2),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNull);
      events.add(identity('second', TrustedIdentityVerification.verified));
      events.addError(StateError('synthetic-private-error'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isNull);
      controller.dispose();
      await events.close();
    },
  );
  test('dispose cancels subscription once', () async {
    var cancelled = 0;
    final events = StreamController<TrustedIncomingIdentity?>.broadcast(
      onCancel: () => cancelled++,
    );
    final controller = TrustedIncomingIdentityController(
      owner: owner,
      events: events.stream,
      isCurrent: (_) => true,
    );
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, 1);
    events.add(identity('late', TrustedIdentityVerification.verified));
    await events.close();
  });
}
