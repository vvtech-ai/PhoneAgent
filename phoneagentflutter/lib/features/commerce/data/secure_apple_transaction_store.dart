import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/apple_transaction_settlement.dart';
import '../domain/payment_launcher.dart';

/// Environment-scoped financial evidence, independent of any account session.
class SecureAppleTransactionStore implements AppleTransactionStore {
  SecureAppleTransactionStore({
    required String scope,
    this.storage = const AppLocalStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key =
           'phoneagent.apple-transactions.v1.${sha256.convert(utf8.encode(scope))}';
  final String key;
  final FlutterSecureStorage storage;

  Future<T> _run<T>(
    Future<T> Function(Map<String, NativePaymentResult>) action,
  ) => PreferenceOperationQueue.run(key, () async {
    final raw = await storage.read(key: key);
    final values = <String, NativePaymentResult>{};
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['schema'] != 1) {
        throw const FormatException('Apple transaction schema');
      }
      for (final item in data['transactions'] as List) {
        final e = NativePaymentResult(
          transactionId: item['transactionId'] as String?,
          signedTransaction: item['signedTransaction'] as String?,
          appAccountToken: item['appAccountToken'] as String?,
          platformProductId: item['platformProductId'] as String?,
        );
        if (!completeAppleEvidence(e) || values.containsKey(e.transactionId)) {
          throw const FormatException('Invalid persisted Apple evidence');
        }
        values[e.transactionId!] = e;
      }
    }
    return action(values);
  });

  Future<void> _write(Map<String, NativePaymentResult> values) => storage.write(
    key: key,
    value: jsonEncode({
      'schema': 1,
      'transactions': values.values
          .map(
            (e) => {
              'transactionId': e.transactionId,
              'signedTransaction': e.signedTransaction,
              'appAccountToken': e.appAccountToken,
              'platformProductId': e.platformProductId,
            },
          )
          .toList(),
    }),
  );

  @override
  Future<List<NativePaymentResult>> read() =>
      _run((v) async => v.values.toList());
  @override
  Future<void> save(NativePaymentResult evidence) => _run((v) async {
    if (!completeAppleEvidence(evidence) ||
        (!v.containsKey(evidence.transactionId) && v.length >= 512)) {
      throw const FormatException('Apple transaction storage unavailable');
    }
    v[evidence.transactionId!] = evidence;
    await _write(v);
  });
  @override
  Future<void> remove(NativePaymentResult evidence) => _run((v) async {
    if (v[evidence.transactionId]?.signedTransaction !=
        evidence.signedTransaction) {
      return;
    }
    v.remove(evidence.transactionId);
    await _write(v);
  });
}
