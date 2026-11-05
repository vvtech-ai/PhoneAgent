import 'dart:async';
import 'dart:math';
import 'sip_lease.dart';
import 'sip_message.dart';
import 'sip_request_builder.dart';
import 'sip_sdp.dart';
import 'sip_wire.dart';
import 'sip_authenticator.dart';
import 'sip_dialog_identity.dart';

enum SipCallPhase { registering, dialing, ringing, connected, ended }

/// Single-use UDP dialog. Retransmits only the same SIP transaction, never redials.
class SipTransactions {
  SipTransactions({
    required this.builder,
    required this.wire,
    required this.onPhase,
    required this.authenticator,
    this.registerTimeout = const Duration(seconds: 15),
    this.inviteTimeout = const Duration(seconds: 65),
    String Function()? token,
  }) : _token = token ?? _randomToken;
  final SipRequestBuilder builder;
  final SipWire wire;
  final void Function(SipCallPhase) onPhase;
  final SipAuthenticator authenticator;
  final Duration registerTimeout, inviteTimeout;
  final String Function() _token;
  Future<SipAudioEndpoint>? _startWork;
  Future<void>? _closeWork;
  SipDialog? _dialog;
  String _inviteBranch = '', _toHeader = '';
  int _inviteCseq = 1, _commandCseq = 1;
  bool _cancelled = false, _cancelSent = false, _byeSent = false;
  bool _invitePending = false, _shutdownFailure = false;
  final _pendingInfo = <int, ({String branch, Completer<void> completion})>{};

  Future<SipAudioEndpoint> start() =>
      _startWork ??= Future<SipAudioEndpoint>.microtask(_start);
  Future<SipAudioEndpoint> _start() async {
    try {
      _check();
      onPhase(SipCallPhase.registering);
      _check();
      final registration = SipRequestBuilder(
        lease: builder.lease,
        target: builder.target,
        localIp: builder.localIp,
        localSipPort: builder.localSipPort,
        localRtpPort: builder.localRtpPort,
        callId: 'reg-${_token()}@phoneagent',
        fromTag: 'reg-${_token()}',
      );
      var seq = 1;
      var branch = _branch();
      var packet = registration.register(branch: branch, cseq: seq);
      await wire.send(packet);
      var response = await _wait(
        registration.callId,
        'REGISTER',
        seq,
        packet,
        registerTimeout,
      );
      if (_challenge(response)) {
        _check();
        seq++;
        branch = _branch();
        packet = registration.register(
          branch: branch,
          cseq: seq,
          authorization: _authorization(
            response,
            'REGISTER',
            registration.registerUri,
          ),
        );
        await wire.send(packet);
        response = await _wait(
          registration.callId,
          'REGISTER',
          seq,
          packet,
          registerTimeout,
        );
      }
      _success(response, 'REGISTER');
      _check();
      onPhase(SipCallPhase.dialing);
      _check();
      _inviteBranch = _branch();
      _invitePending = true;
      packet = builder.invite(branch: _inviteBranch, cseq: _inviteCseq);
      _toHeader = SipMessage.parse(packet).header('to')!;
      await wire.send(packet);
      response = await _wait(
        builder.callId,
        'INVITE',
        _inviteCseq,
        packet,
        inviteTimeout,
      );
      _invitePending = false;
      if (_challenge(response) && !_cancelled) {
        await _ackFailure(response);
        _inviteCseq++;
        _inviteBranch = _branch();
        packet = builder.invite(
          branch: _inviteBranch,
          cseq: _inviteCseq,
          authorization: _authorization(response, 'INVITE', builder.inviteUri),
        );
        _toHeader = SipMessage.parse(packet).header('to')!;
        _invitePending = true;
        await wire.send(packet);
        response = await _wait(
          builder.callId,
          'INVITE',
          _inviteCseq,
          packet,
          inviteTimeout,
        );
        _invitePending = false;
      }
      if (response.status < 200 || response.status >= 300) {
        await _ackFailure(response);
        _success(response, 'INVITE');
      }
      _dialog = builder.dialogFrom(response, _inviteCseq);
      _commandCseq = _inviteCseq;
      await wire.send(
        builder.dialog('ACK', _dialog!, branch: _branch(), cseq: _inviteCseq),
      );
      if (_cancelled) {
        await _bye();
        throw const SipLeaseFailure('CANCELLED');
      }
      final endpoint = SipSdp.parse(response.body);
      onPhase(SipCallPhase.connected);
      return endpoint;
    } catch (error, stack) {
      try {
        await hangup();
      } catch (_) {
        /* Cleanup is reported independently by close. */
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<SipMessage> _wait(
    String callId,
    String method,
    int seq,
    String packet,
    Duration timeout,
  ) async {
    final branch = SipMessage.parse(packet).topViaBranch;
    final watch = Stopwatch()..start();
    Duration? cancelledAt;
    var interval = const Duration(milliseconds: 500);
    var provisional = false;
    while (watch.elapsed < timeout) {
      if (_cancelled) {
        if (method != 'INVITE') throw const SipLeaseFailure('CANCELLED');
        cancelledAt ??= watch.elapsed;
        if (watch.elapsed - cancelledAt >= const Duration(seconds: 3)) {
          throw const SipLeaseFailure('CANCELLED');
        }
      }
      final remaining = timeout - watch.elapsed;
      final message = await wire.receive(
        remaining < interval ? remaining : interval,
      );
      if (message == null) {
        if (!provisional && !_cancelled) await wire.send(packet);
        interval = Duration(
          milliseconds: min(interval.inMilliseconds * 2, 4000),
        );
        continue;
      }
      if (message.method == 'OPTIONS') {
        await wire.send(SipRequestBuilder.ok(message));
        continue;
      }
      if (branch == null ||
          message.topViaBranch != branch ||
          message.header('call-id') != callId ||
          message.cseq != seq ||
          message.cseqMethod != method) {
        continue;
      }
      if (message.status >= 100 && message.status < 200) {
        provisional = true;
        if (method == 'INVITE') {
          if (!_cancelled && message.status >= 180) {
            onPhase(SipCallPhase.ringing);
          }
        }
        continue;
      }
      if (message.status >= 200) return message;
    }
    throw SipLeaseFailure(_cancelled ? 'CANCELLED' : '${method}_TIMEOUT');
  }

  Future<void> holdUntilEnded() async {
    while (!_cancelled) {
      final message = await wire.receive(const Duration(seconds: 1));
      if (message == null) continue;
      if (message.method == 'BYE') {
        final dialog = _dialog;
        if (dialog == null ||
            !matchesSipDialogBye(
              message,
              callId: builder.callId,
              localTag: builder.fromTag,
              remoteHeader: dialog.toHeader,
            )) {
          await wire.send(SipRequestBuilder.rejectDialog(message));
        } else {
          await wire.send(SipRequestBuilder.ok(message));
          _byeSent = true;
          _cancelled = true;
          onPhase(SipCallPhase.ended);
        }
      } else if (message.method == 'OPTIONS') {
        await wire.send(SipRequestBuilder.ok(message));
      } else if (message.header('call-id') == builder.callId) {
        if (message.topViaBranch == _inviteBranch &&
            message.cseqMethod == 'INVITE' &&
            message.cseq == _inviteCseq &&
            message.status >= 200 &&
            message.status < 300 &&
            _dialog != null) {
          await wire.send(
            builder.dialog(
              'ACK',
              _dialog!,
              branch: _branch(),
              cseq: _inviteCseq,
            ),
          );
        } else if (message.cseqMethod == 'INFO' && message.status >= 200) {
          final pending = _pendingInfo[message.cseq];
          if (pending != null && message.topViaBranch == pending.branch) {
            _pendingInfo.remove(message.cseq);
            if (message.status < 300) {
              pending.completion.complete();
            } else {
              pending.completion.completeError(
                const SipLeaseFailure('DTMF_REJECTED'),
              );
            }
          }
        }
      }
    }
    _endInfo();
  }

  Future<void> sendDtmf(String digit) async {
    _check();
    final dialog = _dialog;
    if (dialog == null) throw const SipLeaseFailure('NOT_CONNECTED');
    final seq = ++_commandCseq;
    final branch = _branch();
    final packet = builder.dialog(
      'INFO',
      dialog,
      branch: branch,
      cseq: seq,
      digit: digit,
    );
    final completion = Completer<void>();
    _pendingInfo[seq] = (branch: branch, completion: completion);
    // Attach the error consumer before sending; a remote error can be synchronous.
    final response = completion.future.timeout(const Duration(seconds: 3));
    try {
      await Future.wait<void>([wire.send(packet), response], eagerError: true);
    } finally {
      _pendingInfo.remove(seq);
    }
  }

  Future<void> hangup() async {
    try {
      await _hangup();
    } catch (_) {
      _shutdownFailure = true;
      rethrow;
    }
  }

  Future<void> _hangup() async {
    _cancelled = true;
    _endInfo();
    if (_dialog != null) {
      await _bye();
    } else if (!_cancelSent && _invitePending) {
      _cancelSent = true;
      await wire.send(
        builder.cancel(
          branch: _inviteBranch,
          inviteCseq: _inviteCseq,
          toHeader: _toHeader.isEmpty ? '<${builder.inviteUri}>' : _toHeader,
        ),
      );
    }
  }

  Future<void> _bye() async {
    if (_byeSent || _dialog == null) return;
    _byeSent = true;
    try {
      await wire.send(
        builder.dialog(
          'BYE',
          _dialog!,
          branch: _branch(),
          cseq: ++_commandCseq,
        ),
      );
    } catch (_) {
      _shutdownFailure = true;
      rethrow;
    }
  }

  Future<void> close() => _closeWork ??= _close();
  Future<void> _close() async {
    try {
      try {
        await hangup();
      } catch (_) {
        /* Still wait for in-flight start. */
      }
      try {
        await _startWork;
      } catch (_) {
        /* The start caller observes failure. */
      }
    } finally {
      await wire.close();
    }
    if (_shutdownFailure) {
      throw const SipLeaseFailure('SIP_CLEANUP_UNCONFIRMED');
    }
  }

  void _endInfo() {
    for (final pending in _pendingInfo.values) {
      if (!pending.completion.isCompleted) {
        pending.completion.completeError(const SipLeaseFailure('CANCELLED'));
      }
    }
    _pendingInfo.clear();
  }

  Future<void> _ackFailure(SipMessage response) => wire.send(
    builder.dialog(
      'ACK',
      builder.dialogFrom(response, _inviteCseq, success: false),
      branch: _inviteBranch,
      cseq: _inviteCseq,
    ),
  );
  String _authorization(SipMessage response, String method, String uri) =>
      authenticator.authorization(
        response,
        username: builder.lease.username,
        password: builder.lease.password,
        method: method,
        uri: uri,
        cnonce: _token(),
      );
  static bool _challenge(SipMessage message) =>
      message.status == 401 || message.status == 407;
  static void _success(SipMessage response, String method) {
    if (response.status < 200 || response.status >= 300) {
      throw SipLeaseFailure('${method}_${response.status}');
    }
  }

  void _check() {
    if (_cancelled) throw const SipLeaseFailure('CANCELLED');
  }

  String _branch() => 'z9hG4bK-${_token()}';
  static String _randomToken() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
