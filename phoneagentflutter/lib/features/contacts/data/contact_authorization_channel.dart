import 'package:flutter/services.dart';
import '../domain/contact_authorization.dart';
import '../domain/contact_records.dart';

class ContactAuthorizationChannel implements ContactAuthorizationPort {
  const ContactAuthorizationChannel({
    MethodChannel channel = const MethodChannel(
      'com.vvtech.phone_agent/contacts',
    ),
  }) : _channel = channel;
  final MethodChannel _channel;

  @override
  Future<ContactAuthorization> check() => _invoke('authorization');
  @override
  Future<ContactAuthorization> request() => _invoke('requestAuthorization');

  Future<ContactAuthorization> _invoke(String method) async {
    final value = await _channel.invokeMapMethod<String, dynamic>(method);
    final access = switch (value?['access']) {
      'authorized' => ContactAccess.authorized,
      'limited' => ContactAccess.limited,
      'denied' => ContactAccess.denied,
      'restricted' => ContactAccess.restricted,
      'notDetermined' => ContactAccess.notDetermined,
      'unsupported' => ContactAccess.unsupported,
      _ => throw const FormatException('Invalid contact authorization'),
    };
    if (value?['canRequest'] is! bool) {
      throw const FormatException('Invalid contact request eligibility');
    }
    return ContactAuthorization(access, canRequest: value!['canRequest']);
  }
}
