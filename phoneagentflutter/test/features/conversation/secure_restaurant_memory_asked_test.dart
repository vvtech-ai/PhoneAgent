import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/context/secure_restaurant_memory_asked.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account-scoped offer persists across instances without storing contacts',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final first = SecureRestaurantMemoryAsked('synthetic/a');
      expect(await first.read(), isFalse);
      await first.markAsked();
      expect(await SecureRestaurantMemoryAsked('synthetic/a').read(), isTrue);
      expect(await SecureRestaurantMemoryAsked('synthetic-b').read(), isFalse);
      expect(await const FlutterSecureStorage().readAll(), {
        'restaurant.contact.memory.asked.v1.synthetic%2Fa': 'true',
      });
    },
  );
  test('invalid value is not treated as successful acknowledgement', () async {
    FlutterSecureStorage.setMockInitialValues({
      'restaurant.contact.memory.asked.v1.synthetic': 'garbled',
    });
    expect(
      SecureRestaurantMemoryAsked('synthetic').read(),
      throwsFormatException,
    );
    expect(() => SecureRestaurantMemoryAsked(''), throwsArgumentError);
  });
}
