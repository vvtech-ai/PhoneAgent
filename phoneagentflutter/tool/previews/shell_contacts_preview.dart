import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/contact_entry_providers.dart';
import 'package:phone_agent/features/contacts/domain/contact_authorization.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/app/conversation_providers.dart'
    show phoneContactLookupProvider, nameContactLookupProvider;
import 'package:phone_agent/features/conversation/domain/tools/phone_contact_lookup.dart';
import 'package:phone_agent/features/conversation/domain/tools/name_contact_lookup.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'shell_conversation_ports.dart';

final shellContactsPortsProvider = Provider<ShellContactsPorts>((ref) {
  ref.watch(loginEpochProvider);
  return ShellContactsPorts();
});

class ShellContactsPorts implements SystemDialer {
  final contacts = PreviewContacts();
  final openedNumbers = <String>[];

  @override
  Future<SystemDialResult> open(String number) async {
    openedNumbers.add(number);
    return SystemDialResult.opened;
  }
}

class PreviewContactAuthorization implements ContactAuthorizationPort {
  const PreviewContactAuthorization();
  @override
  Future<ContactAuthorization> check() async =>
      const ContactAuthorization(ContactAccess.authorized);
  @override
  Future<ContactAuthorization> request() => check();
}

List<Override> shellContactsOverrides() => [
  contactAuthorizationPortProvider.overrideWithValue(
    const PreviewContactAuthorization(),
  ),
  phoneContactLookupProvider.overrideWith(
    (ref) => PhoneContactLookup(
      ref.watch(deviceContactSourceProvider),
      ref.watch(shellConversationPortsProvider),
    ),
  ),
  nameContactLookupProvider.overrideWith(
    (ref) => NameContactLookup(
      ref.watch(deviceContactSourceProvider),
      ref.watch(shellConversationPortsProvider),
      const LpinyinContactDictionary(),
    ),
  ),
  contactsSharedFlowEnabledProvider.overrideWithValue(true),
  deviceContactSourceProvider.overrideWith(
    (ref) => ref.watch(shellContactsPortsProvider).contacts,
  ),
  contactDirectoryRepositoryProvider.overrideWith(
    (ref) => ref.watch(shellContactsPortsProvider).contacts.directory,
  ),
  systemDialerProvider.overrideWith(
    (ref) => ref.watch(shellContactsPortsProvider),
  ),
];
