import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invite.dart';
import '../../domain/invite_link_policy.dart';
import '../../domain/invite_store.dart';

String inviteRequestId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256),
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

class PendingInvite {
  const PendingInvite({
    this.code = '',
    this.welcome = false,
    this.loading = true,
    this.busy = false,
    this.error = '',
    this.referral = false,
    this.entryId = 0,
  });
  final String code, error;
  final int entryId;
  final bool welcome, loading, busy, referral;
}

class PendingInviteController extends StateNotifier<PendingInvite> {
  PendingInviteController(this.store) : super(const PendingInvite());
  final InviteStore store;
  String _key = '', _id = '';
  int _generation = 0, _entrySequence = 0;
  Future<void>? _initializing;
  bool _restored = false;
  Future<void> initialize() {
    if (_restored) return Future.value();
    return _initializing ??= _restore().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final data = await store.read('pending');
      if (!mounted || generation != _generation) return;
      final code = data['code'] is String ? data['code'] as String : '';
      _key = data['key'] is String ? data['key'] as String : '';
      _id = data['id'] is String ? data['id'] as String : '';
      _restored = true;
      state = PendingInvite(
        code: code,
        loading: false,
        referral: data['source'] == 'REFERRAL',
      );
    } catch (_) {
      if (mounted) {
        state = const PendingInvite(loading: false, error: '无法读取邀请状态，请重试');
      }
    }
  }

  Future<void> receive(String code) async {
    await initialize();
    if (!_restored) throw const InviteFailure('STORAGE');
    if (!mounted || state.busy || !InviteLinkPolicy.validCode(code)) return;
    await edit(code, welcome: true, referral: true);
  }

  Future<void> edit(
    String code, {
    bool welcome = false,
    bool referral = false,
  }) async {
    await initialize();
    if (!_restored) throw const InviteFailure('STORAGE');
    if (state.busy) return;
    final generation = ++_generation;
    final changed = state.code != code || state.referral != referral;
    final valid = code;
    try {
      await store.write('pending', {
        'code': valid,
        'source': referral ? 'REFERRAL' : 'MANUAL',
        'key': changed ? '' : _key,
        'id': changed ? '' : _id,
      });
      if (!mounted || generation != _generation) return;
      if (changed) {
        _key = '';
        _id = '';
      }
      state = PendingInvite(
        code: valid,
        welcome: welcome,
        entryId: welcome ? ++_entrySequence : 0,
        loading: false,
        referral: referral,
      );
    } catch (_) {
      throw const InviteFailure('STORAGE');
    }
  }

  void continueLogin() {
    state = PendingInvite(
      code: state.code,
      loading: false,
      referral: state.referral,
    );
  }

  Future<String> begin(String phone, String code) async {
    await initialize();
    if (!_restored) throw const InviteFailure('STORAGE');
    if (state.busy) throw const InviteFailure('REQUEST_CONFLICT');
    final source = state.referral ? 'REFERRAL' : 'MANUAL';
    final key = sha256.convert(utf8.encode('$phone|$code|$source')).toString();
    final id = key == _key && _id.isNotEmpty ? _id : inviteRequestId();
    state = PendingInvite(
      code: code,
      loading: false,
      busy: true,
      referral: state.referral,
    );
    try {
      await store.write('pending', {
        'code': code,
        'key': key,
        'id': id,
        'source': state.referral ? 'REFERRAL' : 'MANUAL',
      });
      _key = key;
      _id = id;
      return id;
    } catch (_) {
      finish();
      throw const InviteFailure('STORAGE');
    }
  }

  void finish() {
    if (mounted) {
      state = PendingInvite(
        code: state.code,
        loading: false,
        referral: state.referral,
      );
    }
  }

  Future<void> failed(String code) async {
    finish();
    if ({'REGISTRATION_ABORTED', 'INVITE_ACTIVITY_CHANGED'}.contains(code)) {
      _key = '';
      _id = '';
      await store.write('pending', {
        'code': state.code,
        'source': state.referral ? 'REFERRAL' : 'MANUAL',
      });
    }
  }

  Future<void> clear() async {
    finish();
    await edit('');
  }
}
