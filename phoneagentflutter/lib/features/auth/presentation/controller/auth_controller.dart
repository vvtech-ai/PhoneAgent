import '../../../account_cancellation/domain/account_cancellation.dart';
import '../../../invite/domain/invite.dart';
import '../../../invite/domain/invite_link_policy.dart';
import '../../../invite/presentation/controller/pending_invite_controller.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_gateway.dart';

enum AuthBusy { none, sendingCode, loggingIn }

class AuthState {
  const AuthState({
    this.phone = '',
    this.code = '',
    this.invite = '',
    this.challenge = '',
    this.invitation = false,
    this.busy = AuthBusy.none,
    this.notice = '',
    this.retryPhone = '',
    this.retrySeconds = 0,
    this.outcome,
    this.cancellation,
  });

  final String phone, code, invite, challenge, notice, retryPhone;
  final bool invitation;
  final AuthBusy busy;
  final int retrySeconds;
  final LoginOutcome? outcome;
  final CancellationPendingLogin? cancellation;
  bool get working => busy != AuthBusy.none;
  int get visibleRetrySeconds => phone == retryPhone ? retrySeconds : 0;

  AuthState copyWith({
    String? phone,
    String? code,
    String? invite,
    String? challenge,
    bool? invitation,
    AuthBusy? busy,
    String? notice,
    String? retryPhone,
    int? retrySeconds,
    LoginOutcome? outcome,
    CancellationPendingLogin? cancellation,
    bool clearCancellation = false,
  }) => AuthState(
    phone: phone ?? this.phone,
    code: code ?? this.code,
    invite: invite ?? this.invite,
    challenge: challenge ?? this.challenge,
    invitation: invitation ?? this.invitation,
    busy: busy ?? this.busy,
    notice: notice ?? this.notice,
    retryPhone: retryPhone ?? this.retryPhone,
    retrySeconds: retrySeconds ?? this.retrySeconds,
    outcome: outcome ?? this.outcome,
    cancellation: clearCancellation ? null : cancellation ?? this.cancellation,
  );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._gateway, {
    DateTime Function()? now,
    this.pendingInvite,
    Future<void> Function(LoginOutcome)? onAuthenticated,
  }) : _now = now ?? DateTime.now,
       _onAuthenticated = onAuthenticated,
       super(const AuthState());

  final AuthGateway _gateway;
  final PendingInviteController? pendingInvite;
  final DateTime Function() _now;
  final Future<void> Function(LoginOutcome)? _onAuthenticated;
  LoginOutcome? _pendingSuccess;
  bool _saving = false;
  String? _revokeId;
  int _inviteEdits = 0;
  Future<bool> _inviteSaved = Future.value(true);
  Timer? _ticker;
  DateTime? _retryUntil;
  int _generation = 0;

  void changePhone(String value) {
    if (state.working) return;
    if (state.cancellation != null) keepCancellation();
    final phone = sanitizeLoginPhone(value, state.phone);
    final changed = phone != state.phone;
    if (changed) {
      _pendingSuccess = null;
    }
    state = state.copyWith(
      phone: phone,
      code: changed ? '' : state.code,
      challenge: changed ? '' : state.challenge,
      notice: '',
    );
  }

  void changeCode(String value) {
    if (state.busy != AuthBusy.loggingIn) {
      state = state.copyWith(code: value, notice: '');
    }
  }

  void changeInvite(String value) {
    if (state.working) return;
    state = state.copyWith(invite: value, notice: '');
    if (pendingInvite == null) return;
    _inviteEdits++;
    _inviteSaved = _inviteSaved.then((_) async {
      try {
        await pendingInvite!.edit(value);
        return true;
      } catch (_) {
        if (mounted) state = state.copyWith(notice: '无法保存邀请状态，请重试');
        return false;
      } finally {
        _inviteEdits--;
      }
    });
  }

  void useReferral(String value) {
    if (!state.working && _inviteEdits == 0) {
      state = state.copyWith(invite: value);
    }
  }

  void backToLogin() {
    if (!state.invitation || state.working || _saving) return;
    _generation++;
    pendingInvite?.finish();
    state = state.copyWith(
      invitation: false,
      challenge: '',
      busy: AuthBusy.none,
      notice: '',
    );
  }

  Future<void> sendCode() async {
    refreshCooldown();
    if (state.working || state.visibleRetrySeconds > 0) return;
    if (!isLoginPhone(state.phone)) {
      state = state.copyWith(notice: '请输入正确的手机号码');
      return;
    }
    final generation = ++_generation;
    state = state.copyWith(busy: AuthBusy.sendingCode, notice: '');
    try {
      final result = await _gateway.sendCode(state.phone);
      if (!_isCurrent(generation)) return;
      final seconds = result.cooldownSeconds < 1 ? 1 : result.cooldownSeconds;
      _retryUntil = _now().add(Duration(seconds: seconds));
      state = state.copyWith(
        phone: result.phone,
        retryPhone: result.phone,
        retrySeconds: seconds,
        busy: AuthBusy.none,
        notice: '验证码已发送',
      );
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => refreshCooldown(),
      );
    } catch (error) {
      if (_isCurrent(generation)) {
        _showError(error, fallback: '获取验证失败，请稍后重试');
      }
    }
  }

  Future<void> submit() async {
    if (state.working || state.cancellation != null) return;
    if (_pendingSuccess != null) {
      await _completeLogin(_pendingSuccess!, ++_generation);
      return;
    }
    final challenge = state.invitation ? state.challenge.trim() : '';
    String? invalid;
    if (!isLoginPhone(state.phone)) {
      invalid = '请输入正确的手机号码';
    } else if (challenge.isEmpty && !isSmsCode(state.code)) {
      invalid = '请输入正确的验证码';
    } else if (state.invitation && state.invite.trim().isEmpty) {
      invalid = '请输入邀请码';
    }
    if (invalid != null) {
      state = state.copyWith(notice: invalid);
      return;
    }
    final generation = ++_generation;
    state = state.copyWith(busy: AuthBusy.loggingIn, notice: '');
    try {
      if (!await _inviteSaved) {
        if (_isCurrent(generation)) {
          state = state.copyWith(
            busy: AuthBusy.none,
            notice: '无法保存邀请状态，请重新编辑后重试',
          );
        }
        return;
      }
      if (!_isCurrent(generation)) return;
      final referral =
          state.invitation &&
          InviteLinkPolicy.validCode(state.invite.trim()) &&
          pendingInvite?.state.referral == true;
      final requestId = state.invitation && pendingInvite != null
          ? await pendingInvite!.begin(state.phone, state.invite.trim())
          : null;
      if (!_isCurrent(generation)) return;
      final submission = LoginSubmission(
        phone: state.phone,
        code: challenge.isEmpty ? state.code.trim() : '',
        activationCode: state.invitation ? state.invite.trim() : null,
        loginChallenge: challenge.isEmpty ? null : challenge,
        registrationRequestId: requestId,
        invitationSource: referral ? 'REFERRAL' : null,
      );
      final result = await _gateway.login(submission);
      if (!_isCurrent(generation)) return;
      if (result.cancellation != null) {
        _revokeId = cancellationOperationId();
        state = state.copyWith(
          cancellation: result.cancellation,
          busy: AuthBusy.none,
          code: '',
          notice: '',
        );
      } else if (result.inviteRequired) {
        pendingInvite?.finish();
        state = state.copyWith(
          phone: result.phone,
          invitation: true,
          challenge: result.loginChallenge,
          code: result.loginChallenge.trim().isEmpty ? state.code : '',
          busy: AuthBusy.none,
        );
      } else {
        _pendingSuccess = result;
        await _completeLogin(result, generation);
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        try {
          await pendingInvite?.failed(
            error is InviteFailure ? error.code : 'NETWORK',
          );
        } catch (_) {
          /* Original registration error remains actionable. */
        }
        if (_isCurrent(generation)) {
          _showError(error, fallback: '登录失败，请稍后重试');
        }
      }
    }
  }

  void keepCancellation() {
    if (state.working) return;
    _generation++;
    _revokeId = null;
    _pendingSuccess = null;
    state = state.copyWith(clearCancellation: true, code: '', notice: '');
  }

  Future<void> continueCancellation() async {
    final pending = state.cancellation;
    final gateway = _gateway;
    if (state.working ||
        pending == null ||
        gateway is! CancellationAuthGateway) {
      return;
    }
    final generation = ++_generation;
    state = state.copyWith(busy: AuthBusy.loggingIn, notice: '');
    try {
      final result = await (gateway as CancellationAuthGateway)
          .revokeCancellation(
            pending,
            _revokeId ??= cancellationOperationId(),
            state.phone,
          );
      if (!_isCurrent(generation)) return;
      if (result.cancellation != null ||
          result.inviteRequired ||
          !result.toSession().valid) {
        throw AuthFailure.invalidResponse;
      }
      _pendingSuccess = result;
      state = state.copyWith(clearCancellation: true);
      await _completeLogin(result, generation);
    } catch (error) {
      if (_isCurrent(generation)) {
        _showError(error, fallback: '撤销结果暂未确认，请重试或重新验证登录');
      }
    }
  }

  Future<void> _completeLogin(LoginOutcome result, int generation) async {
    _saving = true;
    state = state.copyWith(busy: AuthBusy.loggingIn, notice: '');
    try {
      await _onAuthenticated?.call(result);
      if (!_isCurrent(generation)) return;
      _pendingSuccess = null;
      _ticker?.cancel();
      _retryUntil = null;
      state = AuthState(phone: result.phone, outcome: result);
    } catch (_) {
      if (_isCurrent(generation)) {
        // SMS may already be consumed. Retry only the local commit.
        state = AuthState(phone: result.phone, notice: '登录已通过，但保存失败，请点击登录重试保存');
      }
    } finally {
      pendingInvite?.finish();
      _saving = false;
    }
  }

  void refreshCooldown() {
    if (!mounted || _retryUntil == null) return;
    final remaining = (_retryUntil!.difference(_now()).inMilliseconds / 1000)
        .ceil();
    state = state.copyWith(retrySeconds: remaining > 0 ? remaining : 0);
    if (remaining <= 0) {
      _ticker?.cancel();
      _retryUntil = null;
    }
  }

  bool _isCurrent(int generation) => mounted && generation == _generation;

  void _showError(Object error, {required String fallback}) {
    if (error == AuthFailure.challengeExpired && state.invitation) {
      state = state.copyWith(invitation: false, challenge: '', code: '');
    }
    final message = switch (error) {
      InviteFailure e => e.message,
      AuthFailure.accountCancelled => '该账号已注销，无法恢复',
      AuthFailure.unavailable => '登录服务尚未接入，请稍后再试',
      AuthFailure.rejected => '验证失败，请检查输入后重试',
      AuthFailure.incorrectCode => '验证码不正确',
      AuthFailure.codeExpired => '验证码已过期或失效，请重新获取',
      AuthFailure.challengeExpired => '登录验证已过期，请返回登录重新获取验证码',
      AuthFailure.invalidInvite => '邀请码无效或已失效，请检查后重试',
      AuthFailure.rateLimited => '操作太频繁，请稍后重试',
      AuthFailure.invalidResponse => '登录服务响应异常，请稍后重试',
      AuthFailure.offline => '当前无网络连接，请检查网络设置',
      AuthFailure.timeout => '网络连接超时，请检查网络设置',
      AuthFailure.network => '暂时无法连接登录服务，请稍后重试',
      _ => fallback,
    };
    state = state.copyWith(busy: AuthBusy.none, notice: message);
  }

  @override
  void dispose() {
    _generation++;
    _pendingSuccess = null;
    pendingInvite?.finish();
    _ticker?.cancel();
    super.dispose();
  }
}
