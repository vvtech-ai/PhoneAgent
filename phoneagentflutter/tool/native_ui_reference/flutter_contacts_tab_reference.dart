import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/contact_entry_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_authorization.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_tab_entry_gate.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_permission_dialog.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contact_tab_entry_coordinator.dart';
import 'package:phone_agent/features/shell/presentation/widgets/floating_navigation.dart';

/// Isolated synthetic entry: no plugin, OS permission, settings or service IO.
void main() {
  final port = _Authorization();
  final contacts = PreviewContacts();
  runApp(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(1),
        contactsSharedFlowEnabledProvider.overrideWithValue(true),
        contactAuthorizationPortProvider.overrideWithValue(port),
        deviceContactSourceProvider.overrideWithValue(contacts),
        contactDirectoryRepositoryProvider.overrideWithValue(
          contacts.directory,
        ),
        contactSettingsLauncherProvider.overrideWithValue(() async {
          port.settings = true;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          platform:
              const String.fromEnvironment('UI_CONTACTS_PLATFORM') == 'android'
              ? TargetPlatform.android
              : TargetPlatform.iOS,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(
              bool.fromEnvironment('UI_CONTACTS_LARGE') ? 2 : 1,
            ),
          ),
          child: child!,
        ),
        home: _Reference(port: port),
      ),
    ),
  );
}

class _Authorization implements ContactAuthorizationPort {
  ContactAuthorization value = const ContactAuthorization(
    ContactAccess.notDetermined,
    canRequest: true,
  );
  bool settings = false;
  bool grant = true;
  @override
  Future<ContactAuthorization> check() async => value;
  @override
  Future<ContactAuthorization> request() async {
    value = ContactAuthorization(
      grant ? ContactAccess.authorized : ContactAccess.denied,
    );
    return value;
  }
}

class _Reference extends StatefulWidget {
  const _Reference({required this.port});
  final _Authorization port;
  @override
  State<_Reference> createState() => _ReferenceState();
}

class _ReferenceState extends State<_Reference> {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    const dialog = String.fromEnvironment('UI_CONTACTS_DIALOG');
    if (dialog == 'consent' || dialog == 'settings') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showContactPermissionDialog(
            context,
            dialog == 'settings'
                ? ContactPermissionDialogKind.settings
                : ContactPermissionDialogKind.consent,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
      child: SafeArea(
        child: Column(
          children: [
            Wrap(
              children: [
                TextButton(
                  onPressed: () {
                    widget.port.grant = false;
                    widget.port.value = const ContactAuthorization(
                      ContactAccess.notDetermined,
                      canRequest: true,
                    );
                    setState(() => tab = 0);
                  },
                  child: const Text('合成拒绝场景'),
                ),
                TextButton(
                  onPressed: () {
                    widget.port.value = const ContactAuthorization(
                      ContactAccess.authorized,
                    );
                    WidgetsBinding.instance.handleAppLifecycleStateChanged(
                      AppLifecycleState.resumed,
                    );
                  },
                  child: const Text('模拟设置授权返回'),
                ),
              ],
            ),
            Expanded(
              child: tab == 1
                  ? const ContactsRoute(loadOnMount: false)
                  : const Center(child: Text('合成首页')),
            ),
            ContactTabEntryGate(
              selected: tab,
              onSelected: (value) => setState(() => tab = value),
              builder: (select) => FloatingNavigation(
                selected: tab,
                onSelected: select,
                onDial: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
