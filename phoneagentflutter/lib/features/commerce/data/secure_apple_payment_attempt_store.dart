import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/apple_payment_attempt.dart';

class SecureApplePaymentAttemptStore implements ApplePaymentAttemptStore {
  SecureApplePaymentAttemptStore({
    required String scope,
    required this.isCurrent,
    this.storage = const AppLocalStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key =
           'phoneagent.apple-attempts.v1.${sha256.convert(utf8.encode(scope))}';
  final String key;
  final bool Function() isCurrent;
  final FlutterSecureStorage storage;
  void _guard() {
    if (!isCurrent()) throw StateError('Apple attempt owner changed');
  }

  Future<T> _run<T>(
    Future<T> Function(Map<String, ApplePaymentAttempt>) action,
  ) => PreferenceOperationQueue.run(key, () async {
    _guard();
    final raw = await storage.read(key: key);
    _guard();
    final values = <String, ApplePaymentAttempt>{};
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['schema'] != 1) {
        throw const FormatException('Apple attempts schema');
      }
      for (final item in data['attempts'] as List) {
        final attempt = ApplePaymentAttempt.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        if (values.containsKey(attempt.orderNo)) {
          throw const FormatException('Duplicate Apple order');
        }
        values[attempt.orderNo] = attempt;
      }
    }
    return action(values);
  });
  Future<void> _write(Map<String, ApplePaymentAttempt> values) async {
    _guard();
    await storage.write(
      key: key,
      value: jsonEncode({
        'schema': 1,
        'attempts': values.values.map((e) => e.toJson()).toList(),
      }),
    );
    _guard();
  }

  @override
  Future<List<ApplePaymentAttempt>> read() =>
      _run((v) async => v.values.toList());
  @override
  Future<void> save(ApplePaymentAttempt attempt) => _run((v) async {
    v[attempt.orderNo] = attempt;
    await _write(v);
  });
  @override
  Future<void> remove(String orderNo, String attemptId) => _run((v) async {
    if (v[orderNo]?.id != attemptId) return;
    v.remove(orderNo);
    await _write(v);
  });
}
