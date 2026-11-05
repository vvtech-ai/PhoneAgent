import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/contact_records.dart';
import '../controller/contacts_controller.dart';
import '../widgets/contact_list_row.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onRequestPermission,
    required this.onOpen,
    this.onSettings,
  });
  final ContactsState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRequestPermission;
  final ValueChanged<ContactRecord> onOpen;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(22, 8, 22, 10),
        child: Text(
          '联系人',
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            color: ShellTokens.ink,
          ),
        ),
      ),
      if (state.deviceLoading) const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => RefreshIndicator(
            onRefresh: onRefresh,
            child: _showAuthorizedEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: const Center(
                        child: Text(
                          '暂无联系人',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const PageStorageKey('contacts-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    itemCount: _headers.length + state.contacts.length,
                    itemBuilder: (context, index) {
                      final headers = _headers;
                      if (index < headers.length) return headers[index];
                      final row = index - headers.length;
                      final contact = state.contacts[row];
                      return ContactListRow(
                        key: ValueKey(
                          'contact-row-${contact.name}-${contact.key}',
                        ),
                        contact: contact,
                        showDivider: row != state.contacts.length - 1,
                        onOpen: () => onOpen(contact),
                      );
                    },
                  ),
          ),
        ),
      ),
    ],
  );

  List<Widget> get _headers => [
    if (state.deviceError.isNotEmpty)
      _message(state.deviceError, '重试', onRefresh),
    if (state.access == ContactAccess.limited)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const Text('仅显示已授权的联系人', style: ShellTokens.subtitle),
            if (onSettings != null)
              TextButton(onPressed: onSettings, child: const Text('去设置授权')),
          ],
        ),
      ),
    if (!state.deviceLoading &&
        state.contacts.isEmpty &&
        state.deviceError.isEmpty)
      _empty(),
  ];

  bool get _showAuthorizedEmpty =>
      !state.deviceLoading &&
      state.contacts.isEmpty &&
      state.access == ContactAccess.authorized &&
      state.deviceError.isEmpty;

  Widget _empty() => switch (state.access) {
    ContactAccess.unknown || ContactAccess.notDetermined => _message(
      '授权后可显示本机通讯录，不会自动上传整本通讯录。',
      '允许读取联系人',
      onRequestPermission,
    ),
    ContactAccess.denied => _message(
      '尚未获得通讯录权限。若系统不再弹窗，请到系统设置中允许访问。',
      '重新检查权限',
      onRequestPermission,
      settings: true,
    ),
    ContactAccess.restricted => _message(
      '此设备限制了通讯录访问，请检查系统设置。',
      '重新检查',
      onRefresh,
    ),
    ContactAccess.unsupported => _message('当前平台无法读取系统通讯录。', '重新检查', onRefresh),
    ContactAccess.authorized ||
    ContactAccess.limited => _message('暂无可显示的联系人', '刷新', onRefresh),
  };

  Widget _message(
    String message,
    String action,
    VoidCallback callback, {
    bool settings = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center, style: ShellTokens.subtitle),
        const SizedBox(height: 10),
        TextButton(onPressed: callback, child: Text(action)),
        if (settings && onSettings != null)
          TextButton(onPressed: onSettings, child: const Text('去设置授权')),
      ],
    ),
  );
}
