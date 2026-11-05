import 'package:flutter/services.dart';

class DeviceCommerceLegalDocument {
  const DeviceCommerceLegalDocument();
  Future<void> open(String address) async {
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid published agreement');
    }
    await const MethodChannel(
      'phone_agent/legal_documents',
    ).invokeMethod<void>('openPublishedAgreement', uri.toString());
  }
}
