import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/account_session.dart';
import '../../domain/auth_gateway.dart';
import '../../domain/auth_session.dart';

enum SessionPhase { restoring, signedOut, signedIn, restoreFailed }

class SessionState {
  const SessionState(this.phase, {this.session, this.loginOutcome});
  final SessionPhase phase;
  final AuthSession? session;
  // Initial points/grants are in-memory events, not replayed at every restart.
  final LoginOutcome? loginOutcome;
}

class SessionController extends StateNotifier<SessionState>
    implements AccountSession {
  SessionController(this._store)
    : super(const SessionState(SessionPhase.restoring));
  final SessionStore _store;
  int _generation = 0;
  bool _writing = false;
  bool _releasing = false;
  final _releaseListeners = <Future<void> Function()>{};

  /// Presentation can release account-bound subscriptions before providers
  /// observe a new identity. No UI dependency or timer belongs in this owner.
  void Function() addReleaseListener(Future<void> Function() release) {
    _releaseListeners.add(release);
    return () => _releaseListeners.remove(release);
  }

  Future<void> _releasePreviousIdentity() async {
    if (state.phase != SessionPhase.signedIn) return;
    _releasing = true;
    await Future.wait([
      for (final release in [..._releaseListeners]) release(),
    ]);
  }

  @override
  AccountCredentials? get credentials {
    final session = state.session;
    return !_releasing &&
            state.phase == SessionPhase.signedIn &&
            session != null
        ? AccountCredentials(
            session.accountId,
            session.accessToken,
            _generation,
          )
        : null;
  }

  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials) ||
        credentials?.token != expected.token ||
        _writing) {
      return false;
    }
    final old = state.session!;
    final updated = AuthSession(
      accountId: old.accountId,
      phone: old.phone,
      accessToken: token,
      displayName: old.displayName,
    );
    if (!updated.valid) throw AuthFailure.invalidResponse;
    _writing = true;
    try {
      await _store.write(updated);
      if (!mounted || !expected.sameLogin(credentials)) return false;
      state = SessionState(
        SessionPhase.signedIn,
        session: updated,
        loginOutcome: state.loginOutcome,
      );
      return true;
    } catch (_) {
      throw AuthFailure.storage;
    } finally {
      _writing = false;
    }
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) async {
    if (expected.sameLogin(credentials) &&
        credentials?.token == expected.token) {
      await signOut();
    }
  }

  Future<void> restore() async {
    if (_writing) return;
    final generation = ++_generation;
    await _releasePreviousIdentity();
    if (!mounted || generation != _generation) return;
    _releasing = false;
    state = const SessionState(SessionPhase.restoring);
    try {
      final session = await _store.read();
      if (!mounted || generation != _generation) return;
      if (session != null && !session.valid) throw AuthFailure.invalidResponse;
      state = SessionState(
        session == null ? SessionPhase.signedOut : SessionPhase.signedIn,
        session: session,
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        state = const SessionState(SessionPhase.restoreFailed);
      }
    }
  }

  Future<void> accept(LoginOutcome outcome) async {
    final session = outcome.toSession();
    if (outcome.inviteRequired || !session.valid) {
      throw AuthFailure.invalidResponse;
    }
    if (_writing) throw AuthFailure.storage;
    final generation = ++_generation;
    _writing = true;
    try {
      await _store.write(session);
      if (mounted && generation == _generation) {
        await _releasePreviousIdentity();
        if (!mounted || generation != _generation) return;
        _releasing = false;
        state = SessionState(
          SessionPhase.signedIn,
          session: session,
          loginOutcome: outcome,
        );
      }
    } catch (_) {
      throw AuthFailure.storage;
    } finally {
      _writing = false;
    }
  }

  Future<void> signOut() async {
    if (_writing) throw AuthFailure.storage;
    ++_generation;
    _writing = true;
    try {
      await _store.clear();
      if (mounted) {
        await _releasePreviousIdentity();
        if (!mounted) return;
        _releasing = false;
        state = const SessionState(SessionPhase.signedOut);
      }
    } catch (_) {
      throw AuthFailure.storage;
    } finally {
      _writing = false;
    }
  }
}
