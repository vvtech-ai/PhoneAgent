import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../../../core/diagnostics/native_crash_importer.dart';

String nativeCrashScope(String storageScope) =>
    sha256.convert(utf8.encode(storageScope)).toString();

class DeviceNativeCrashPort implements NativeCrashPort {
  const DeviceNativeCrashPort({
    MethodChannel channel = const MethodChannel('phone_agent/native_crash'),
  }) : _channel = channel;
  final MethodChannel _channel;

  @override
  Future<void> bind(String? scope) =>
      _channel.invokeMethod<void>('bind', {'scope': scope});

  @override
  Future<List<NativeCrashSummary>> read(String scope) async {
    final result = await _channel.invokeMethod<Object?>('read', {
      'scope': scope,
    });
    if (result is! List || result.length > 32) {
      throw const FormatException('Invalid crash batch');
    }
    return result.map((row) {
      if (row is! Map) throw const FormatException('Invalid crash row');
      return NativeCrashSummary.fromMap(row, scope);
    }).toList();
  }

  @override
  Future<void> acknowledge(String scope, List<String> ids) =>
      _channel.invokeMethod<void>('acknowledge', {'scope': scope, 'ids': ids});
}
