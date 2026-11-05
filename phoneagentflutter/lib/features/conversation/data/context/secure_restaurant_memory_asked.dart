import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../domain/context/restaurant_contact_memory_offer.dart';

/// Device persistence is account-scoped; no contact or memory content is stored.
class SecureRestaurantMemoryAsked implements RestaurantMemoryAskedStore {
  SecureRestaurantMemoryAsked(
    String accountId, {
    this.storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : _key =
           'restaurant.contact.memory.asked.v1.${Uri.encodeComponent(accountId)}' {
    if (accountId.trim().isEmpty) throw ArgumentError('Missing memory account');
  }
  final FlutterSecureStorage storage;
  final String _key;
  @override
  Future<bool> read() async {
    final value = await storage.read(key: _key);
    if (value != null && value != 'true') {
      throw const FormatException('Invalid restaurant memory asked flag');
    }
    return value == 'true';
  }

  @override
  Future<void> markAsked() => storage.write(key: _key, value: 'true');
}
