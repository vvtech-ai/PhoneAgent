import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart'
    show currentAccountIdProvider;
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

/// Tool-only synthetic contacts, in-memory notes, no device/plugin/service IO.
void main() {
  final contacts = PreviewContacts();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(environment: 'local', apiBaseUrl: ''),
        ),
        contactsSharedFlowEnabledProvider.overrideWithValue(true),
        deviceContactSourceProvider.overrideWithValue(contacts),
        contactDirectoryRepositoryProvider.overrideWithValue(
          contacts.directory,
        ),
        currentAccountIdProvider.overrideWithValue('synthetic-reference'),
        loginEpochProvider.overrideWithValue(1),
        homeRepositoryProvider.overrideWithValue(const _Home()),
        systemDialerProvider.overrideWithValue(const _Dial()),
        contactSettingsLauncherProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(
              bool.fromEnvironment('UI_CONTACTS_LARGE') ? 2 : 1,
            ),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: NativePageBackground(child: SafeArea(child: ContactsRoute())),
        ),
      ),
    ),
  );
}

class _Home implements HomeRepository {
  const _Home();
  @override
  Future<HomeConfig> load() async => const HomeConfig(
    'synthetic',
    [HomeSlogan('s', '', '')],
    [
      HomeCard(
        id: 'synthetic',
        title: '合成可用技能',
        subtitle: '仅用于联系人页面对照',
        status: HomeCardStatus.enabled,
        action: HomeAction.skill,
        skillId: 'synthetic',
      ),
    ],
  );
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async =>
      config.slogans.first;
}

class _Dial implements SystemDialer {
  const _Dial();
  @override
  Future<SystemDialResult> open(String number) async =>
      SystemDialResult.unsupported;
}
