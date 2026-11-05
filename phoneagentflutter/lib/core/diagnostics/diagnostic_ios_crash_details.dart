/// Symbolication evidence only. Never accept exception reasons, registers,
/// full paths, memory contents or arbitrary vendor payloads.
class DiagnosticIosCrashDetails {
  DiagnosticIosCrashDetails.fromJson(Map<Object?, Object?> value) {
    if (value['schema'] != 1 && value['schema'] != 2) {
      throw const FormatException('Crash schema');
    }
    _data = {
      'schema': value['schema'] as int,
      for (final key in const [
        'signal',
        'exception',
        'appVersion',
        'appBuild',
        'osVersion',
        'architecture',
        'deviceModel',
      ])
        key: _token(value[key]),
    };
    final frames = value['frames'];
    if (frames is! List ||
        frames.length > (value['schema'] == 2 ? 1024 : 128)) {
      throw const FormatException('Crash frames');
    }
    _data['frames'] = [for (final frame in frames) _frame(frame)];
    if (value['truncated'] is bool) _data['truncated'] = value['truncated']!;
    if (value['schema'] == 2) {
      _data['faultAddress'] = _hex(value['faultAddress']);
      _data['signalCode'] = _token(value['signalCode']);
      final run = value['runId'];
      if (run is! String ||
          !RegExp(
            r'^(unknown|[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12})$',
          ).hasMatch(run)) {
        throw const FormatException('Crash run');
      }
      _data['runId'] = run;
      for (final key in ['threadCount', 'frameCount']) {
        final count = value[key];
        if (count is! int || count < 0 || count > 10000000) {
          throw const FormatException('Crash count');
        }
        _data[key] = count;
      }
    }
  }
  late final Map<String, Object> _data;

  static String _token(Object? value) {
    if (value is! String ||
        !RegExp(r'^[A-Za-z0-9_.+,()-]{1,96}$').hasMatch(value)) {
      throw const FormatException('Crash metadata');
    }
    return value;
  }

  static Map<String, Object> _frame(Object? value) {
    if (value is! Map ||
        value['thread'] is! int ||
        (value['thread'] as int) < -1 ||
        (value['thread'] as int) > 65535 ||
        value['crashed'] is! bool) {
      throw const FormatException('Crash frame');
    }
    final uuid = value['uuid'];
    if (uuid is! String ||
        !RegExp(
          r'^(unknown|[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})$',
        ).hasMatch(uuid)) {
      throw const FormatException('Crash image');
    }
    return {
      'thread': value['thread'] as int,
      'crashed': value['crashed'] as bool,
      'image': _token(value['image']),
      'uuid': uuid,
      for (final key in const ['base', 'pc', 'offset']) key: _hex(value[key]),
    };
  }

  static String _hex(Object? value) {
    if (value is! String || !RegExp(r'^[a-fA-F0-9]{1,16}$').hasMatch(value)) {
      throw const FormatException('Crash address');
    }
    return value;
  }

  Map<String, Object> toJson() => Map.unmodifiable(_data);
}
