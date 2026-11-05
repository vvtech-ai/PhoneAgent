import '../../domain/trusted_caller_failure_message.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/trusted_caller.dart';

class TrustedCallerState {
  const TrustedCallerState({
    this.status = TrustedCallerStatus.unknown,
    this.busy = false,
    this.error = '',
    this.needsIntroduction = false,
  });
  final TrustedCallerStatus status;
  final bool busy, needsIntroduction;
  final String error;
}

/// Owns a settings presentation, never the account's incoming call service.
class TrustedCallerController extends StateNotifier<TrustedCallerState> {
  TrustedCallerController({
    required this.owner,
    required TrustedCallerPort port,
    required bool Function(TrustedCallerOwner) isCurrent,
    this.onCleanupFailure,
    this.ensureAccount,
  }) : _port = port,
       _isCurrent = isCurrent,
       super(const TrustedCallerState());

  final TrustedCallerOwner owner;
  final Future<bool> Function(TrustedCallerOwner)? ensureAccount;
  final TrustedCallerPort _port;
  final bool Function(TrustedCallerOwner) _isCurrent;
  final void Function(String code)? onCleanupFailure;
  Future<void>? _pending;
  int _generation = 0;
  bool _surfaceReleased = false;
  bool _invalidated = false;

  bool _current(int generation) {
    if (!mounted || _invalidated || generation != _generation) return false;
    if (owner.valid && _isCurrent(owner)) return true;
    _generation++;
    _invalidated = true;
    state = const TrustedCallerState(error: '登录账号或绑定号码已改变');
    unawaited(_releaseSurface());
    return false;
  }

  Future<void> refresh() => _run(open: false);

  Future<void> prepareEntry() => _run(open: false, entry: true);

  Future<void> openEntrySettings() {
    if (_pending != null) return _pending!;
    if (state.status == TrustedCallerStatus.unknown ||
        state.status == TrustedCallerStatus.unavailable) {
      return Future<void>.value();
    }
    return _run(open: true, entry: true);
  }

  Future<void> openSettings() {
    if (_pending != null) return _pending!;
    if (state.status == TrustedCallerStatus.unknown ||
        state.status == TrustedCallerStatus.unavailable) {
      return Future<void>.value();
    }
    return _run(open: true);
  }

  Future<bool> markIntroductionSeen() {
    if (_pending != null) return Future<bool>.value(false);
    final generation = _generation;
    if (!_current(generation) ||
        state.status == TrustedCallerStatus.unknown ||
        state.status == TrustedCallerStatus.unavailable) {
      return Future<bool>.value(false);
    }
    if (!state.needsIntroduction) return Future<bool>.value(true);
    final completion = Completer<bool>();
    final pending = completion.future.then<void>((_) {});
    _pending = pending;
    unawaited(
      _markIntroduction(
        generation,
      ).then(completion.complete, onError: (_) => completion.complete(false)),
    );
    return completion.future.whenComplete(() {
      if (identical(_pending, pending)) _pending = null;
    });
  }

  Future<bool> _markIntroduction(int generation) async {
    final previous = state;
    state = TrustedCallerState(
      status: previous.status,
      busy: true,
      needsIntroduction: previous.needsIntroduction,
    );
    try {
      final guide = _port;
      if (guide is! TrustedCallerGuidePort) {
        throw const TrustedCallerFailure('SDK_GUIDE_UNAVAILABLE');
      }
      await (guide as TrustedCallerGuidePort).markIntroductionSeen(owner);
      if (!_current(generation)) return false;
      state = TrustedCallerState(status: previous.status);
      return true;
    } catch (_) {
      if (_current(generation)) {
        state = TrustedCallerState(
          status: previous.status,
          needsIntroduction: previous.needsIntroduction,
          error: '可信来电说明记录未完成，请重试',
        );
      }
      return false;
    }
  }

  Future<void> _run({required bool open, bool entry = false}) {
    if (_pending != null) return _pending!;
    final generation = _generation;
    if (!_current(generation)) return Future<void>.value();
    final completion = Completer<void>();
    final operation = completion.future;
    _pending = operation;
    unawaited(
      _perform(
        generation,
        open: open,
        entry: entry,
      ).then((_) => completion.complete(), onError: completion.completeError),
    );
    return operation.whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
  }

  Future<void> _perform(
    int generation, {
    required bool open,
    bool entry = false,
  }) async {
    final previous = state.status;
    final previousIntroduction = state.needsIntroduction;
    var reading = false;
    state = TrustedCallerState(
      status: previous,
      busy: true,
      needsIntroduction: previousIntroduction,
    );
    try {
      if (open) {
        await _port.openSettings(owner);
      } else {
        final ensure = ensureAccount;
        if (ensure != null && !await ensure(owner)) {
          throw const TrustedCallerFailure('SDK_ACCOUNT_UNCONFIRMED');
        }
        if (!_current(generation)) return;
        final available = await _port.prepare(owner);
        if (!_current(generation)) return;
        if (!available) {
          state = const TrustedCallerState(
            status: TrustedCallerStatus.unavailable,
            error: '当前环境的可信来电服务暂不可用',
          );
          return;
        }
      }
      if (!_current(generation)) return;
      if (entry) {
        final port = _port;
        state = TrustedCallerState(
          status: TrustedCallerStatus.readyToConfigure,
          needsIntroduction: port is TrustedCallerEntryPort
              ? (port as TrustedCallerEntryPort).needsIntroduction
              : false,
        );
        return;
      }
      reading = true;
      final report = await _port.readStatus(owner);
      if (!_current(generation)) return;
      if (!report.owner.matches(owner) ||
          (report.status == TrustedCallerStatus.authorized &&
              !report.explicitSdkAuthorization)) {
        throw const TrustedCallerFailure('INVALID_AUTHORIZATION_REPORT');
      }
      state = TrustedCallerState(
        status: report.status,
        needsIntroduction: report.needsIntroduction,
      );
    } catch (error) {
      if (_current(generation)) {
        state = TrustedCallerState(
          status: open && !reading ? previous : TrustedCallerStatus.unknown,
          error: trustedCallerFailureMessage(
            error,
            open
                ? TrustedCallerOperation.open
                : entry
                ? TrustedCallerOperation.prepare
                : TrustedCallerOperation.refresh,
          ),
          needsIntroduction: open && !reading ? previousIntroduction : false,
        );
      }
    }
  }

  Future<void> _releaseSurface() async {
    if (_surfaceReleased) return;
    _surfaceReleased = true;
    try {
      await _port.releaseSurface(owner);
    } catch (_) {
      onCleanupFailure?.call('TRUSTED_CALLER_SURFACE_RELEASE_UNCONFIRMED');
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_releaseSurface());
    super.dispose();
  }
}
