import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/data/migrating_session_store.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/legacy_session_source.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';

const oldSession = AuthSession(
  accountId: 'phone-13800000000',
  phone: '13800000000',
  accessToken: 'synthetic-old',
);
const freshSession = AuthSession(
  accountId: 'phone-13900000000',
  phone: '13900000000',
  accessToken: 'synthetic-new',
);

class _Destination implements SessionStore {
  _Destination(this.events);
  final List<String> events;
  AuthSession? value;
  bool failRead = false, failWrite = false, failClear = false;
  @override
  Future<AuthSession?> read() async {
    events.add('new.read');
    if (failRead) throw StateError('synthetic');
    return value;
  }

  @override
  Future<void> write(AuthSession session) async {
    events.add('new.write');
    if (failWrite) throw StateError('synthetic');
    value = session;
  }

  @override
  Future<void> clear() async {
    events.add('new.clear');
    if (failClear) throw StateError('synthetic');
    value = null;
  }
}

class _Source implements LegacySessionSource {
  _Source(this.events);
  final List<String> events;
  AuthSession? value = oldSession;
  bool consumed = false, failConsume = false, failRead = false;
  Completer<void>? readGate;
  @override
  Future<AuthSession?> read() async {
    events.add('old.read');
    final snapshot = consumed ? null : value;
    await readGate?.future;
    if (failRead) throw StateError('synthetic');
    return snapshot;
  }

  @override
  Future<void> consume() async {
    events.add('old.consume');
    if (failConsume) throw StateError('synthetic');
    consumed = true;
  }
}

void main() {
  late List<String> events;
  late _Source source;
  late _Destination destination;
  late MigratingSessionStore store;
  setUp(() {
    events = [];
    source = _Source(events);
    destination = _Destination(events);
    store = MigratingSessionStore(destination, source, scope: 'synthetic-prod');
  });
  test('upgrade writes secure target before consuming source', () async {
    expect(await store.read(), oldSession);
    expect(events, ['new.read', 'old.read', 'new.write', 'old.consume']);
    expect(
      source.value,
      oldSession,
      reason: 'legacy data retained for rollback',
    );
    events.clear();
    expect(
      await MigratingSessionStore(
        destination,
        source,
        scope: store.scope,
      ).read(),
      oldSession,
    );
    expect(events, ['new.read', 'old.consume']);
  });
  test('existing Flutter account wins without reading old identity', () async {
    destination.value = freshSession;
    source.failRead = true;
    expect(await store.read(), freshSession);
    expect(source.consumed, isTrue);
    expect(events, ['new.read', 'old.consume']);
  });
  test('damaged secure target never falls back to a legacy account', () async {
    destination.failRead = true;
    await expectLater(store.read(), throwsStateError);
    expect(events, ['new.read']);
    expect(source.consumed, isFalse);
  });
  test(
    'secure write failure retains source for explicit restore retry',
    () async {
      destination.failWrite = true;
      await expectLater(store.read(), throwsStateError);
      expect(source.consumed, isFalse);
      destination.failWrite = false;
      expect(await store.read(), oldSession);
      expect(source.consumed, isTrue);
    },
  );
  test(
    'marker failure retries from the saved target, not old credentials',
    () async {
      source.failConsume = true;
      await expectLater(store.read(), throwsStateError);
      expect(destination.value, oldSession);
      source.failConsume = false;
      events.clear();
      expect(await store.read(), oldSession);
      expect(events, ['new.read', 'old.consume']);
    },
  );
  test(
    'logout before first restore prevents any later legacy resurrection',
    () async {
      await store.clear();
      expect(events, ['old.consume', 'new.clear']);
      expect(
        await MigratingSessionStore(
          destination,
          source,
          scope: store.scope,
        ).read(),
        isNull,
      );
      expect(destination.value, isNull);
      expect(source.value, oldSession);
    },
  );
  test('barrier failure prevents logout and replacement mutation', () async {
    destination.value = freshSession;
    source.failConsume = true;
    await expectLater(store.clear(), throwsStateError);
    await expectLater(store.write(oldSession), throwsStateError);
    expect(destination.value, freshSession);
    expect(events, ['old.consume', 'old.consume']);
  });
  test('new login seals legacy even when new storage write fails', () async {
    destination.failWrite = true;
    await expectLater(store.write(freshSession), throwsStateError);
    expect(source.consumed, isTrue);
    expect(await store.read(), isNull);
    destination.failWrite = false;
    await store.write(freshSession);
    expect(await store.read(), freshSession);
  });
  test(
    'failed clear retains target and retries without reading legacy',
    () async {
      await store.read();
      destination.failClear = true;
      await expectLater(store.clear(), throwsStateError);
      expect(await store.read(), oldSession);
      destination.failClear = false;
      await store.clear();
      expect(await store.read(), isNull);
    },
  );
  test(
    'concurrent read and logout serialize; late restore cannot sign in',
    () async {
      source.readGate = Completer<void>();
      final controller = SessionController(store);
      final restore = controller.restore();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['new.read', 'old.read']);
      final logout = controller.signOut();
      source.readGate!.complete();
      await Future.wait([restore, logout]);
      expect(controller.state.phase, SessionPhase.signedOut);
      expect(destination.value, isNull);
      expect(await store.read(), isNull);
      controller.dispose();
    },
  );
  test(
    'recreated store logout cannot be overwritten by an old restore',
    () async {
      source.readGate = Completer<void>();
      final restore = store.read();
      await Future<void>.delayed(Duration.zero);
      final replacement = MigratingSessionStore(
        destination,
        source,
        scope: store.scope,
      );
      final logout = replacement.clear();
      await Future<void>.delayed(Duration.zero);
      source.readGate!.complete();
      await Future.wait([restore, logout]);
      expect(destination.value, isNull);
      expect(await replacement.read(), isNull);
    },
  );
  test(
    'different storage scopes do not wait for a blocked legacy read',
    () async {
      source.readGate = Completer<void>();
      final restore = store.read();
      await Future<void>.delayed(Duration.zero);
      final otherDestination = _Destination([]);
      final other = MigratingSessionStore(
        otherDestination,
        _Source([]),
        scope: 'synthetic-other',
      );
      try {
        await other.write(freshSession).timeout(const Duration(seconds: 1));
        expect(otherDestination.value, freshSession);
        expect(destination.value, isNull);
      } finally {
        source.readGate!.complete();
        await restore;
      }
    },
  );
  test(
    'duplicate restores import once; no login reward event is invented',
    () async {
      final result = await Future.wait([store.read(), store.read()]);
      expect(result, [oldSession, oldSession]);
      expect(events.where((e) => e == 'new.write'), hasLength(1));
      final controller = SessionController(store);
      await controller.restore();
      expect(controller.state.phase, SessionPhase.signedIn);
      expect(controller.state.loginOutcome, isNull);
      controller.dispose();
    },
  );
  test(
    'absent legacy does not write or seal; invalid session never writes',
    () async {
      source.value = null;
      expect(await store.read(), isNull);
      expect(events, ['new.read', 'old.read']);
      const invalid = AuthSession(accountId: '', phone: '', accessToken: '');
      await expectLater(
        store.write(invalid),
        throwsA(AuthFailure.invalidResponse),
      );
      expect(source.consumed, isFalse);
      source.value = invalid;
      await expectLater(store.read(), throwsA(AuthFailure.invalidResponse));
      expect(destination.value, isNull);
    },
  );
}
