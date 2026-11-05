import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/contact_records.dart';

/// No permission request on construction or refresh; only explicit user action.
class DeviceContactChannel implements DeviceContactSource {
  const DeviceContactChannel({
    MethodChannel channel = const MethodChannel(
      'com.vvtech.phone_agent/contacts',
    ),
    bool? supported,
  }) : _channel = channel,
       _supported = supported;
  final MethodChannel _channel;
  final bool? _supported;

  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async {
    final supported =
        _supported ??
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS));
    if (!supported) return DeviceContactsSnapshot(ContactAccess.unsupported);
    final result = await _channel.invokeMapMethod<String, dynamic>('load', {
      'requestPermission': requestPermission,
    });
    final access = switch (result?['access']) {
      'authorized' => ContactAccess.authorized,
      'limited' => ContactAccess.limited,
      'denied' => ContactAccess.denied,
      'restricted' => ContactAccess.restricted,
      'notDetermined' => ContactAccess.notDetermined,
      'unsupported' => ContactAccess.unsupported,
      _ => throw const FormatException('Invalid contacts permission result'),
    };
    if (access != ContactAccess.authorized && access != ContactAccess.limited) {
      return DeviceContactsSnapshot(access);
    }
    final rows = result?['rows'];
    if (rows is! List) throw const FormatException('Invalid contacts result');
    return DeviceContactsSnapshot(
      access,
      rows.map((row) {
        if (row is! Map ||
            row['name'] is! String ||
            row['phone'] is! String ||
            row['normalizedPhone'] != null &&
                row['normalizedPhone'] is! String ||
            row['label'] != null && row['label'] is! String ||
            row['contactId'] != null && row['contactId'] is! String) {
          throw const FormatException('Invalid contact row');
        }
        return DeviceContactRow(
          name: row['name'],
          phone: row['phone'],
          normalizedPhone: row['normalizedPhone'] ?? '',
          label: row['label'] ?? '',
          contactId: row['contactId'] ?? '',
        );
      }).toList(),
    );
  }
}
