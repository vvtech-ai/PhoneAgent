import 'package:flutter/material.dart';
import '../../domain/contact_records.dart';
import 'contact_avatar.dart';

/// Shared native row presentation; device and directory IO stay in controllers.
class ContactListRow extends StatelessWidget {
  const ContactListRow({
    super.key,
    required this.contact,
    required this.showDivider,
    required this.onOpen,
  });
  final ContactRecord contact;
  final bool showDivider;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: true,
    label: '${contact.name}，${contact.phone}',
    onTap: onOpen,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('contact-${contact.name}-${contact.key}'),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: Color(0x143C3C43)))
                : null,
          ),
          child: Row(
            children: [
              ContactAvatar(name: contact.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        letterSpacing: 0,
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${contact.phone} · 本机通讯录联系人',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        letterSpacing: 0,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
