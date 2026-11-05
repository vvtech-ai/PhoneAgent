/// Native boundary observations; no vendor parameters or exception messages.
class DiagnosticIosTraceDetails {
  DiagnosticIosTraceDetails.fromJson(Map<Object?, Object?> value) {
    if (value['schema'] != 1) throw const FormatException('Trace schema');
    final events = value['events'];
    if (events is! List || events.length > 128) {
      throw const FormatException('Trace size');
    }
    _data = {
      'schema': 1,
      'runId': _uuid(value['runId']),
      'runnerUUID': value['runnerUUID'] == 'unknown'
          ? 'unknown'
          : _uuid(value['runnerUUID']),
      for (final key in [
        'appVersion',
        'appBuild',
        'configuredSdk',
        'osVersion',
        'deviceModel',
      ])
        key: _token(value[key]),
      for (final key in ['dropped', 'writeFailures', 'unbound'])
        key: _integer(value[key], 0, 0x7fffffff),
      'events': [for (final event in events) _event(event)],
    };
  }
  late final Map<String, Object> _data;
  static const eventNames = {
    'prepare.enter',
    'prepare.cached',
    'prepare.claimed',
    'prepare.ready',
    'sdk.init.enter',
    'sdk.init.exit',
    'sdk.meta.enter',
    'sdk.meta.exit',
    'capture.enter',
    'capture.accepted',
    'container.presented',
    'permissions.enter',
    'permissions.result',
    'audio.prepare.enter',
    'audio.prepare.exit',
    'sdk.verify.enter',
    'sdk.verify.return',
    'sdk.callback',
    'sdk.callback.main',
    'sdk.callback.stale',
    'sdk.exception',
    'finish.enter',
    'finish.duplicate',
    'finish.reply',
    'container.close',
    'container.closed',
    'abort.enter',
    'abort.stale',
    'abort.accepted',
    'reset.enter',
    'reset.exit',
    'release.wait',
    'release.immediate',
    'engine.detach',
    'plugin.dealloc',
    'busy',
    'unavailable',
    'preview.prepare',
    'preview.result',
    'preview.retry',
    'app.inactive',
    'app.background',
    'app.foreground',
    'app.active',
    'app.terminate',
    'app.memoryWarning',
    'audio.interruption',
    'audio.routeChange',
    'audio.mediaLost',
    'audio.mediaReset',
    'recorder.ready',
    'recorder.unavailable',
  };
  static Map<String, Object> _event(Object? value) {
    if (value is! Map ||
        !eventNames.contains(value['event']) ||
        value['main'] is! bool) {
      throw const FormatException('Trace event');
    }
    final thread = value['thread'];
    if (thread is! String || !RegExp(r'^\d{1,20}$').hasMatch(thread)) {
      throw const FormatException('Trace thread');
    }
    return {
      'event': value['event'] as String,
      'seq': _integer(value['seq'], 1, 0x1fffffffffffff),
      'time': _integer(value['time'], 946684800000, 4102444800000),
      'monotonicUs': _integer(value['monotonicUs'], 0, 0x1fffffffffffff),
      if (value['queueLagUs'] != null)
        'queueLagUs': _integer(value['queueLagUs'], 0, 0x1fffffffffffff),
      'thread': thread,
      'main': value['main'] as bool,
      'session': value['session'] == '' ? '' : _uuid(value['session']),
      'actor': value['actor'] == '' ? '' : _uuid(value['actor']),
      'flags': _integer(value['flags'], 0, 255),
      'code': _integer(value['code'], -0x80000000, 0x7fffffff),
      if (value['category'] != null) 'category': _token(value['category']),
      if (value['mode'] != null) 'mode': _token(value['mode']),
      if (value['sampleRate'] != null)
        'sampleRate': _integer(value['sampleRate'], 0, 384000),
      for (final key in ['inputs', 'outputs'])
        if (value[key] != null) key: _ports(value[key]),
    };
  }

  static List<String> _ports(Object? value) {
    if (value is! List || value.length > 8) {
      throw const FormatException('Trace route');
    }
    return value.map(_token).toList();
  }

  static int _integer(Object? value, int min, int max) {
    if (value is! int || value < min || value > max) {
      throw const FormatException('Trace number');
    }
    return value;
  }

  static String _token(Object? value) {
    if (value is! String ||
        !RegExp(r'^[A-Za-z0-9_.+,()-]{1,96}$').hasMatch(value)) {
      throw const FormatException('Trace token');
    }
    return value;
  }

  static String _uuid(Object? value) {
    if (value is! String ||
        !RegExp(
          r'^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
        ).hasMatch(value)) {
      throw const FormatException('Trace identity');
    }
    return value;
  }

  Map<String, Object> toJson() => Map.unmodifiable(_data);
}
