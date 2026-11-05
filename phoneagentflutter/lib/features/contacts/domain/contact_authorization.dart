import 'contact_records.dart';

/// Permission-only result; checking entry must never enumerate the address book.
class ContactAuthorization {
  const ContactAuthorization(this.access, {this.canRequest = false});
  final ContactAccess access;
  final bool canRequest;
  bool get canRead =>
      access == ContactAccess.authorized || access == ContactAccess.limited;
}

abstract interface class ContactAuthorizationPort {
  Future<ContactAuthorization> check();
  Future<ContactAuthorization> request();
}
