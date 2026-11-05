import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Account-scoped: survives onboarding removal, disposed on credential changes.
class InitializationModelSwitchController extends StateNotifier<String> {
  InitializationModelSwitchController(this.selectModel, this.onSaved)
    : super('');
  final Future<void> Function(String) selectModel;
  final void Function() onSaved;
  bool _busy = false;
  Future<void> select(String id, String name) async {
    if (!mounted) return;
    if (_busy) {
      state = '通话模型正在切换中，请稍后重试';
      return;
    }
    _busy = true;
    state = '';
    try {
      await selectModel(id);
      if (!mounted) return;
      onSaved();
      state = '通话模型已切换为 $name';
    } catch (_) {
      if (mounted) state = '通话模型切换失败，请检查网络或本地服务连接';
    } finally {
      _busy = false;
    }
  }
}
