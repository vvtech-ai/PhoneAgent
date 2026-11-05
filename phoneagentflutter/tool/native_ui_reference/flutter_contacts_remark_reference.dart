import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_remark_editor.dart';

/// Synthetic seeded editor only. No system or account contact operations.
class FlutterContactsRemarkReference extends StatelessWidget {
  const FlutterContactsRemarkReference({super.key, required this.scene});
  final String scene;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      contactsControllerProvider.overrideWith((ref) {
        final source = PreviewContacts();
        return _EditorReferenceController(source, scene);
      }),
    ],
    child: Scaffold(
      body: NativePageBackground(
        child: ColoredBox(
          color: const Color(0x380F0F12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: const Color(0xF5FFFFFF),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: const ContactRemarkEditor(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EditorReferenceController extends ContactsController {
  _EditorReferenceController(PreviewContacts source, String scene)
    : super(source, source.directory) {
    state = ContactsState(
      selected: const ContactRecord(
        name: '合成联系人',
        phone: '00000001',
        systemDialPhone: '00000001',
      ),
      access: ContactAccess.authorized,
      editing: true,
      draft: scene == 'contacts-remark' ? '' : '合成备注：请在七点联系。',
      saving: scene == 'contacts-remark-busy',
      saveError: scene == 'contacts-remark-error' ? '合成保存失败，请稍后重试' : '',
    );
  }
}
