import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class DeviceLegacyCallAdmissionSource {
  const DeviceLegacyCallAdmissionSource();
  static const channel = MethodChannel('phone_agent/legacy_call_admission');

  Future<Set<String>> read(
    String account,
    String session,
    Iterable<String> aliases,
  ) async {
    if ([
      account,
      session,
    ].any((s) => s.trim().isEmpty || s.contains('\u0000'))) {
      throw ArgumentError('Missing or invalid legacy marker scope');
    }
    final values = aliases.toSet();
    if (values.isEmpty ||
        values.length > 1024 ||
        values.any((s) => s.trim().isEmpty)) {
      throw ArgumentError('Invalid legacy marker aliases');
    }
    final byHash = {
      for (final alias in values)
        sha256
                .convert(utf8.encode('$account\u0000$session\u0000$alias'))
                .toString():
            alias,
    };
    final data = await channel.invokeMapMethod<String, Object?>('read', {
      'keys': byHash.keys.toList(),
    });
    if (data == null) return {}; // Nonproduction package: no source.
    final markers = data['markers'];
    if (data['version'] != 1 ||
        markers is! Map ||
        markers.length != byHash.length ||
        markers.keys.any((key) => !byHash.containsKey(key)) ||
        markers.values.any((value) => value is! bool)) {
      throw const FormatException('Invalid legacy marker response');
    }
    return {
      for (final entry in byHash.entries)
        if (markers[entry.key] == true) entry.value,
    };
  }
}
