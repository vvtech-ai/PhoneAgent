import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/contacts/data/contact_authorization_channel.dart';
import '../features/contacts/domain/contact_authorization.dart';

final contactAuthorizationPortProvider = Provider<ContactAuthorizationPort>(
  (ref) => const ContactAuthorizationChannel(),
);
