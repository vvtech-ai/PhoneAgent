import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/trusted_caller.dart';
import '../../domain/trusted_caller_home_guide.dart';

class TrustedCallerHomeGuideState {
  const TrustedCallerHomeGuideState({this.eligible = false, this.error = ''});
  final bool eligible;
  final String error;
}

class TrustedCallerHomeGuideController
    extends StateNotifier<TrustedCallerHomeGuideState> {
  TrustedCallerHomeGuideController({
    required this.owner,
    required this.store,
    required this.ensureAccount,
  }) : super(const TrustedCallerHomeGuideState());
  final TrustedCallerOwner owner;
  final TrustedCallerHomeGuideStore store;
  final Future<bool> Function(TrustedCallerOwner) ensureAccount;
  int _revision = 0;
  bool _shown = false;

  Future<void> load() async {
    final revision = ++_revision;
    if (_shown) return;
    try {
      if (!await ensureAccount(owner) || !mounted || revision != _revision) {
        return;
      }
      final eligible = await store.eligible(owner);
      if (mounted && revision == _revision && !_shown) {
        state = TrustedCallerHomeGuideState(eligible: eligible);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        state = const TrustedCallerHomeGuideState();
      }
    }
  }

  Future<bool> record({bool disabled = false}) async {
    _shown = true;
    ++_revision;
    state = const TrustedCallerHomeGuideState();
    try {
      await store.record(owner, disabled: disabled);
      return mounted;
    } catch (_) {
      if (mounted) {
        state = const TrustedCallerHomeGuideState(error: '可信来电提示偏好保存失败，请重试');
      }
      return false;
    }
  }
}
