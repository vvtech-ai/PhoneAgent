import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/contacts/data/lpinyin_contact_dictionary.dart';
import '../features/dialer/domain/dial_contact_suggestion.dart';
import '../features/dialer/presentation/controller/dial_contacts_controller.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';

final dialContactsProvider =
    StateNotifierProvider.autoDispose<
      DialContactsController,
      DialContactsState
    >((ref) {
      ref.watch(loginEpochProvider);
      final controller = DialContactsController(
        ref.watch(deviceContactSourceProvider),
        const DialSuggestionPolicy(LpinyinContactDictionary()),
      );
      controller.load();
      return controller;
    });
