import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/confirmation_billing.dart';

class SecureConfirmationBillingStore implements ConfirmationBillingStore {
  SecureConfirmationBillingStore({
    required this.scope,
    this.legacyRead,
    this.isCurrent,
    this.storage = const AppLocalStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  });
  final String scope;
  final FlutterSecureStorage storage;
  final bool Function()? isCurrent;
  final Future<ConfirmationBillingSnapshot?> Function(
    ConfirmationBillingRequest,
  )?
  legacyRead;
  void _guard() {
    if (isCurrent?.call() == false) throw StateError('Billing owner changed');
  }

  String _key(String session, String alias) =>
      'phoneagent.confirmation-billing.v1.${sha256.convert(utf8.encode(jsonEncode([scope, session, alias])))}';

  @override
  Future<ConfirmationBillingSnapshot> resolve(
    ConfirmationBillingRequest request,
    ConfirmationBillingSnapshot current,
  ) => PreferenceOperationQueue.run('confirmation-billing:$scope', () async {
    _guard();
    if (scope.isEmpty ||
        request.sessionId.trim().isEmpty ||
        request.aliases.isEmpty) {
      throw ArgumentError('Missing billing identity');
    }
    final keys = [
      for (final alias in request.aliases) _key(request.sessionId, alias),
    ];
    ConfirmationBillingSnapshot? existing;
    for (final key in keys) {
      final raw = await storage.read(key: key);
      _guard();
      if (raw == null) continue;
      final value = jsonDecode(raw);
      if (value is! Map || value['schema'] != 1) {
        throw const FormatException('Invalid stored billing snapshot');
      }
      final parsed = ConfirmationBillingSnapshot.fromJson(value);
      existing ??= parsed;
    }
    final saved = existing ?? await legacyRead?.call(request);
    _guard();
    if (saved == null && !request.captureCurrent) {
      return const ConfirmationBillingSnapshot();
    }
    final snapshot = saved ?? current;
    final encoded = jsonEncode({'schema': 1, ...snapshot.toJson()});
    // One scope queue also serializes requests with overlapping aliases.
    for (final key in keys) {
      _guard();
      await storage.write(key: key, value: encoded);
      _guard();
    }
    return snapshot;
  });
}
