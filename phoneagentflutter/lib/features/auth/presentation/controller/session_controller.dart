import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/account_session.dart';
import '../../domain/auth_gateway.dart';
import '../../domain/auth_session.dart';

enum SessionPhase { restoring, signedOut, signedIn, restoreFailed }

class SessionState {
  const SessionState(
    this.phase, {
    this.session,
    this.loginOutcome,
    this.businessBlocked = false,
    this.invalidationReason,
  });
  final SessionPhase phase;
  final bool businessBlocked;
  final SessionInvalidationReason? invalidationReason;
  final AuthSession? session;
  // Initial points/grants are in-memory events, not replayed at every restart.
  final LoginOutcome? loginOutcome;
}

class SessionController extends StateNotifier<SessionState>
    implements AccountSession, AccountSessionInvalidation {
  SessionController(this._store)
    : super(const SessionState(SessionPhase.restoring));
  final SessionStore _store;
  int _generation = 0;
  int? _blockedEpoch;
  bool _writing = false;
  bool _releasing = false;
  AccountCredentials? _invalidatingOwner, _queuedOwner;
  SessionInvalidationReason? _reason, _queuedReason;
  Future<void>? _exitFuture;
  bool _cleanupRunning = false;
  final _cancellationGuards = <Object>{};
  bool get invalidationCleanupRunning => _cleanupRunning;
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

  /// Account-scoped presentation identity survives the cleanup barrier; transport credentials do not.
  bool get isSignedOut => state.phase == SessionPhase.signedOut;
  int? get identityEpoch => state.phase == SessionPhase.signedIn
      ? _blockedEpoch ?? _generation
      : null;

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
      _drainInvalidation();
    }
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) =>
      invalidateSession(expected, SessionInvalidationReason.expired);

  bool _matches(AccountCredentials expected) =>
      expected.sameLogin(credentials) && credentials?.token == expected.token;

  @override
  Future<void> invalidateSession(
    AccountCredentials expected,
    SessionInvalidationReason reason,
  ) {
    if (!mounted) return Future.value();
    if (expected.sameLogin(_invalidatingOwner) &&
        expected.token == _invalidatingOwner?.token) {
      return _exitFuture ?? Future.value();
    }
    if (!_matches(expected)) return Future.value();
    if (_writing || _cancellationGuards.isNotEmpty) {
      _queuedOwner = expected;
      _queuedReason = reason;
      return Future.value();
    }
    _invalidatingOwner = expected;
    _reason = reason;
    _cleanupRunning = true;
    _blockBusiness(reason);
    return _exitFuture = _performInvalidation();
  }

  Future<void> _performInvalidation() async {
    try {
      await signOut();
    } catch (_) {
      /* The blocked root offers explicit cleanup retry. */
    } finally {
      _cleanupRunning = false;
      if (mounted && state.businessBlocked && _reason != null) {
        _blockBusiness(_reason);
      }
    }
  }

  Future<void> retryInvalidation() {
    if (!mounted ||
        !state.businessBlocked ||
        _reason == null ||
        _cleanupRunning ||
        _writing) {
      return _exitFuture ?? Future.value();
    }
    _cleanupRunning = true;
    _blockBusiness(_reason);
    return _exitFuture = _performInvalidation();
  }

  /// A submitted cancellation owns its result lookup and success feedback.
  void Function() deferInvalidationForCancellation() {
    final token = Object();
    _cancellationGuards.add(token);
    return () {
      if (_cancellationGuards.remove(token)) _drainInvalidation();
    };
  }

  void _drainInvalidation() {
    if (!mounted ||
        _writing ||
        _cancellationGuards.isNotEmpty ||
        _queuedOwner == null) {
      return;
    }
    final owner = _queuedOwner!, reason = _queuedReason!;
    _queuedOwner = null;
    _queuedReason = null;
    unawaited(invalidateSession(owner, reason));
  }

  void _resetInvalidation() {
    _reason = null;
    _queuedOwner = null;
    _queuedReason = null;
    _invalidatingOwner = null;
    _exitFuture = null;
    _cancellationGuards.clear();
  }

  SessionInvalidationReason? takeInvalidationNotice() {
    if (!mounted || state.phase != SessionPhase.signedOut) return null;
    final result = state.invalidationReason;
    if (result != null) {
      _reason = null;
      state = const SessionState(SessionPhase.signedOut);
    }
    return result;
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
      _resetInvalidation();
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
    if (outcome.cancellation != null ||
        outcome.inviteRequired ||
        !session.valid) {
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
        _blockedEpoch = null;
        _resetInvalidation();
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
      _drainInvalidation();
    }
  }

  /// Server accepted cancellation: immediately deny account requests, even if local cleanup fails.
  void blockBusinessForCancellation() {
    _reason = null;
    _queuedOwner = null;
    _queuedReason = null;
    _blockBusiness(null);
  }

  void _blockBusiness(SessionInvalidationReason? reason) {
    if (!mounted || state.phase != SessionPhase.signedIn) return;
    _blockedEpoch ??= _generation;
    _releasing = true;
    state = SessionState(
      SessionPhase.signedIn,
      session: state.session,
      businessBlocked: true,
      invalidationReason: reason,
    );
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
        _blockedEpoch = null;
        state = SessionState(
          SessionPhase.signedOut,
          invalidationReason: _reason,
        );
      }
    } catch (_) {
      throw AuthFailure.storage;
    } finally {
      _writing = false;
      _drainInvalidation();
    }
  }
}
