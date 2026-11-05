import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../domain/confirmation_billing.dart';

class DeviceLegacyConfirmationBilling {
  const DeviceLegacyConfirmationBilling();
  static const channel = MethodChannel(
    'phone_agent/legacy_confirmation_billing',
  );
  Future<ConfirmationBillingSnapshot?> read(
    String account,
    ConfirmationBillingRequest request,
  ) async {
    if ([
      account,
      request.sessionId,
    ].any((s) => s.trim().isEmpty || s.contains('\u0000'))) {
      throw ArgumentError('Invalid billing owner');
    }
    String digest(String text) => sha256.convert(utf8.encode(text)).toString();
    final pairs = [
      for (final alias in request.aliases)
        [
          digest('$account\u0000${request.sessionId}\u0000$alias'),
          digest('$account\u0000$alias'),
        ],
    ];
    final keys = pairs.expand((p) => p).toSet().toList();
    if (keys.isEmpty || keys.length > 1024) {
      throw ArgumentError('Invalid billing keys');
    }
    final result = await channel.invokeMapMethod<String, Object?>('read', {
      'keys': keys,
    });
    if (result == null) return null;
    final values = result['snapshots'];
    if (result['version'] != 1 ||
        values is! Map ||
        values.length != keys.length ||
        values.keys.any((k) => !keys.contains(k)) ||
        values.values.any(
          (v) => v != null && (v is! String || v.length > 4096),
        )) {
      throw const FormatException('Invalid legacy billing response');
    }
    for (final pair in pairs) {
      final raw = values[pair[0]] ?? values[pair[1]];
      if (raw == null) continue;
      return ConfirmationBillingSnapshot.fromJson(jsonDecode(raw as String));
    }
    return null;
  }
}
