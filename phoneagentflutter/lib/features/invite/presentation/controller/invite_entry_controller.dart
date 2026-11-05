import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invite_device.dart';
import '../../domain/invite_link_policy.dart';
import 'pending_invite_controller.dart';

enum InviteEntryEvent {
  received,
  rejected,
  queued,
  existingAccount,
  registrationDispatched,
  saveFailed,
  streamFailed,
}

class InviteEntryController extends StateNotifier<String> {
  InviteEntryController(
    this.device,
    this.policy,
    this.pending, {
    this.deduplicateUrls = true,
    this.onEvent,
  }) : super('');
  final bool deduplicateUrls;
  final void Function(InviteEntryEvent)? onEvent;
  final InviteDevice device;
  final InviteLinkPolicy policy;
  final PendingInviteController pending;
  StreamSubscription<String>? _subscription;
  bool _ready = false, _signedIn = false;
  String? _queued, _last;
  DateTime? _lastAt;
  Future<void> start() async {
    var receivedHotLink = false;
    _subscription = device.links.listen((url) {
      receivedHotLink = true;
      receive(url);
    }, onError: (Object _) => _report(InviteEntryEvent.streamFailed));
    try {
      final initial = await device.initialLink();
      if (mounted && !receivedHotLink && initial != null) receive(initial);
    } catch (_) {
      _report(InviteEntryEvent.streamFailed);
    }
  }

  void session({required bool ready, required bool signedIn}) {
    final becameSignedIn = signedIn && !_signedIn;
    _ready = ready;
    _signedIn = signedIn;
    if (becameSignedIn) {
      pending.clear().catchError((Object _) {
        if (mounted) state = '登录成功，邀请状态清理失败，请稍后重试';
      });
    }
    final queued = _queued;
    if (ready && queued != null) {
      _queued = null;
      _dispatch(queued);
    }
  }

  void receive(String url) {
    _report(InviteEntryEvent.received);
    final code = policy.parse(url);
    if (code == null) {
      _report(InviteEntryEvent.rejected);
      return;
    }
    final now = DateTime.now();
    if (deduplicateUrls &&
        _last == url &&
        _lastAt != null &&
        now.difference(_lastAt!).inSeconds < 1) {
      return;
    }
    _last = url;
    _lastAt = now;
    if (!_ready) {
      _report(InviteEntryEvent.queued);
      _queued = code;
      return;
    }
    _dispatch(code);
  }

  void _dispatch(String code) {
    if (_signedIn) {
      _report(InviteEntryEvent.existingAccount);
      state = '';
      state = '本次邀请奖励仅限新用户';
      return;
    }
    _report(InviteEntryEvent.registrationDispatched);
    pending.receive(code).catchError((Object _) {
      _report(InviteEntryEvent.saveFailed);
      if (mounted) state = '邀请状态保存失败，请重新打开链接';
    });
  }

  void _report(InviteEntryEvent event) {
    try {
      onEvent?.call(event);
    } catch (_) {
      // Diagnostics must never prevent invitation handling.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
