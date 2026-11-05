import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';

/// Authorized synthetic display only; no system contact, dialer or permission IO.
class FlutterContactsReference extends StatelessWidget {
  const FlutterContactsReference({super.key, required this.scene});
  final String scene;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
      child: SafeArea(
        child: scene.startsWith('contacts-detail')
            ? ContactDetailPage(
                state: ContactsState(
                  selected: const ContactRecord(
                    name: '合成联系人',
                    phone: '00000001',
                    systemDialPhone: '00000001',
                  ),
                  directoryLoading: scene == 'contacts-detail-loading',
                  directory: scene == 'contacts-detail-saved'
                      ? const [
                          ContactDirectoryEntry(
                            phone: '00000001',
                            description: '合成备注：请在七点联系。',
                          ),
                        ]
                      : const [],
                ),
                onBack: () {},
                onEdit: () {},
                onRetry: () {},
                onCall: () {},
                onTask: () {},
                onDelete: () {},
              )
            : ContactsPage(
                state: ContactsState(
                  access: ContactAccess.authorized,
                  contacts: scene == 'contacts-empty'
                      ? const []
                      : const [
                          ContactRecord(
                            name: '合成联系人',
                            phone: '00000001',
                            systemDialPhone: '00000001',
                          ),
                          ContactRecord(
                            name: '合成用于长姓名省略核对的联系人',
                            phone: '00000002',
                            systemDialPhone: '00000002',
                          ),
                        ],
                ),
                onRefresh: () async {},
                onRequestPermission: () {},
                onOpen: (_) {},
              ),
      ),
    ),
  );
}
