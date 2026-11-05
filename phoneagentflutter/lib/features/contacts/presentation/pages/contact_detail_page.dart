import 'package:flutter/material.dart';
import '../controller/contacts_controller.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/contact_profile_action.dart';

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onEdit,
    required this.onRetry,
    required this.onCall,
    required this.onTask,
    this.dialBusy = false,
    this.onDelete,
  });
  final ContactsState state;
  final VoidCallback onBack, onEdit, onRetry, onCall, onTask;
  final bool dialBusy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final contact = state.selected;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Semantics(
                  container: true,
                  button: true,
                  enabled: true,
                  label: '返回联系人',
                  onTap: onBack,
                  excludeSemantics: true,
                  child: IconButton(
                    tooltip: '返回联系人',
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: Transform.translate(
                      offset: const Offset(0, -2),
                      child: const Text(
                        '‹',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: contact == null
                ? [const Text('联系人已不可用，请返回列表重新选择。')]
                : [
                    Center(
                      child: ContactAvatar(name: contact.name, large: true),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      contact.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      contact.phone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        letterSpacing: 0,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '本机通讯录联系人',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
          ),
        ),
        if (contact != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Row(
              children: [
                Expanded(
                  child: ContactProfileAction(
                    label: '拨打电话',
                    primary: true,
                    onTap: dialBusy ? null : onCall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ContactProfileAction(label: '发起任务', onTap: onTask),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
