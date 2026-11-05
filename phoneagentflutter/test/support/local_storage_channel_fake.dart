import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';

/// Platform boundary fake only; does not claim native encryption/file protection.
void installLocalStorageChannelFake() {
  final values = <String, String>{};
  var installed = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
        if (call.method == 'installed') return installed;
        if (call.method == 'markInstalled') {
          installed = true;
          return null;
        }
        final args = call.arguments as Map;
        final key = '${args['kind']}:${args['key']}';
        switch (call.method) {
          case 'read':
            return values[key];
          case 'write':
            values[key] = args['value'] as String;
            return null;
          case 'delete':
            values.remove(key);
            return null;
          default:
            throw StateError('Unexpected local storage operation');
        }
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, null),
  );
}
