import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../domain/home_card_preferences.dart';

class SecureHomeCardPreferences implements HomeCardPreferenceRepository {
  SecureHomeCardPreferences(
    List<String> scope, {
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : key = 'home.cards.${sha256.convert(utf8.encode(jsonEncode(scope)))}';
  final String key;
  final FlutterSecureStorage storage;
  @override
  Future<HomeCardPreferences> read() async {
    final raw = await storage.read(key: key);
    if (raw == null) return const HomeCardPreferences();
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['order'] is! List ||
        value['visibility'] is! Map ||
        (value['order'] as List).any((v) => v is! String) ||
        (value['visibility'] as Map).entries.any(
          (e) => e.key is! String || e.value is! bool,
        )) {
      throw const FormatException('Invalid home preference');
    }
    return HomeCardPreferences(
      order: (value['order'] as List).cast<String>(),
      visibility: (value['visibility'] as Map).cast<String, bool>(),
    );
  }

  @override
  Future<void> save(HomeCardPreferences preferences) => storage.write(
    key: key,
    value: jsonEncode({
      'order': preferences.order,
      'visibility': preferences.visibility,
    }),
  );
}
