import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/dial_recent_call.dart';
import '../domain/dial_recent_source.dart';

/// Never asks for permission. iOS/Web must not attempt a system call-log read.
class DeviceCallLogChannel implements DialRecentCallSource {
  const DeviceCallLogChannel({
    MethodChannel channel = const MethodChannel(
      'com.vvtech.phone_agent/call_log',
    ),
    bool? supported,
  }) : _channel = channel,
       _supported = supported;
  final MethodChannel _channel;
  final bool? _supported;

  @override
  Future<DialRecentSnapshot> load() async {
    if (!(_supported ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android))) {
      return const DialRecentSnapshot(DialRecentAccess.unsupported);
    }
    final result = await _channel.invokeMapMethod<String, dynamic>('load');
    final access = switch (result?['access']) {
      'ready' => DialRecentAccess.ready,
      'denied' => DialRecentAccess.denied,
      'failed' => DialRecentAccess.failed,
      _ => throw const FormatException('Invalid call log access'),
    };
    if (access != DialRecentAccess.ready) return DialRecentSnapshot(access);
    final rows = result?['rows'];
    if (rows is! List) throw const FormatException('Invalid call log rows');
    final records = <DialRecentCall>[];
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          row['phone'] is! String ||
          row['name'] is! String ||
          row['startedAtMillis'] is! int) {
        throw const FormatException('Invalid call log row');
      }
      final id = (row['id'] as String).trim();
      if (id.isEmpty) throw const FormatException('Missing call log identity');
      final record = DialRecentCall(
        id: id,
        phone: (row['phone'] as String).trim(),
        name: (row['name'] as String).trim(),
        startedAtMillis: row['startedAtMillis'] as int,
        source: DialRecentSource.system,
      );
      if (record.selectable) records.add(record);
    }
    return DialRecentSnapshot(access, mergeDialRecentCalls(records, const []));
  }
}
