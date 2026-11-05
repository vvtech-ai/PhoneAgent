import 'package:flutter/foundation.dart';
import '../../../conversation/domain/context/agent_clock.dart';
import '../../../conversation/domain/context/agent_context_builder.dart';
import '../../../conversation/domain/tools/conversation_permission.dart';

/// Isolated synthetic inputs; no account, HTTP or platform channels are held.
class AgentContextPreviewController extends ChangeNotifier {
  final _source = _PreviewContextSource();
  late final _builder = AgentContextBuilder(
    location: () async => {'lat': 22.5, 'lng': 114.0},
    clock: _source,
    permissions: _source,
  );
  Map<String, Object?> result = const {};
  bool busy = false, _closed = false;
  int turns = 0;
  String get zone => _source.zone;
  String get mode => _source.mode;
  static const zones = [
    'Asia/Shanghai',
    'America/Los_Angeles',
    'Asia/Kathmandu',
  ];
  static const modes = ['已授权', '未授权', '不可用', '读取失败'];

  void setZone(String value) {
    if (!zones.contains(value) || busy || _closed) return;
    _source.zone = value;
    notifyListeners();
  }

  void setMode(String value) {
    if (!modes.contains(value) || busy || _closed) return;
    _source.mode = value;
    notifyListeners();
  }

  void advanceDay() {
    if (busy || _closed) return;
    _source.now = _source.now.add(const Duration(days: 1));
    notifyListeners();
  }

  Future<void> prepare() async {
    if (busy || _closed) return;
    busy = true;
    notifyListeners();
    final next = await _builder.prepare();
    if (_closed) return;
    result = next;
    turns++;
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _builder.close();
    super.dispose();
  }
}

class _PreviewContextSource
    implements AgentClockSource, ConversationPermissionSource {
  DateTime now = DateTime.utc(2026, 9, 18, 23, 59);
  String zone = 'Asia/Shanghai', mode = '已授权';
  @override
  Future<AgentClockSnapshot> read() async => AgentClockSnapshot(
    epochMillis: now.millisecondsSinceEpoch,
    offsetSeconds: switch (zone) {
      'America/Los_Angeles' => -7 * 3600,
      'Asia/Kathmandu' => 20700,
      _ => 8 * 3600,
    },
    timezone: zone,
  );

  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    if (request) throw StateError('Preview must only read');
    if (permission == ConversationPermission.documentPicker) {
      return PermissionGrant.granted;
    }
    return switch (mode) {
      '已授权' => PermissionGrant.granted,
      '未授权' => PermissionGrant.denied,
      '不可用' => PermissionGrant.unavailable,
      _ => throw StateError('Synthetic permission failure'),
    };
  }
}
