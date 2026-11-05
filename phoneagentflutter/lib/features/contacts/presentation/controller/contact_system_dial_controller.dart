import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dialer/domain/system_dialer.dart';
import '../../domain/contact_system_dial_target.dart';

/// Owns only OS handoff, independent of dial-pad input and conversation state.
class ContactSystemDialController extends StateNotifier<bool> {
  ContactSystemDialController(this._dialer) : super(false);

  final SystemDialer _dialer;

  /// Null means ignored or obsolete; empty means the OS accepted the handoff.
  Future<String?> open(String raw) async {
    if (!mounted || state) return null;
    final target = contactSystemDialTarget(raw);
    if (target.isEmpty) return '联系人号码格式不正确';
    state = true;
    SystemDialResult result;
    try {
      result = await _dialer.open(target);
    } catch (_) {
      result = SystemDialResult.failed;
    }
    if (!mounted) return null;
    state = false;
    return switch (result) {
      SystemDialResult.opened => '',
      SystemDialResult.invalid => '联系人号码格式不正确',
      SystemDialResult.unsupported => '未找到可用的系统拨号应用',
      SystemDialResult.failed => '无法打开系统拨号盘，请稍后重试',
    };
  }
}
