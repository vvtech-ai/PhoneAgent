import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

class _Home implements HomeRepository {
  bool fail = true;
  int calls = 0;
  @override
  Future<HomeConfig> load() async {
    calls++;
    if (fail) throw StateError('synthetic');
    return const HomeConfig(
      'synthetic',
      [HomeSlogan('s', '', '')],
      [
        HomeCard(
          id: 's',
          title: '合成可用技能',
          subtitle: '',
          status: HomeCardStatus.enabled,
          action: HomeAction.skill,
          skillId: 'synthetic',
        ),
      ],
    );
  }

  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async =>
      config.slogans.first;
}

class _Dialer implements SystemDialer {
  int calls = 0;
  @override
  Future<SystemDialResult> open(String number) async {
    calls++;
    return SystemDialResult.opened;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform skill error retries; covered and disposed detail actions do nothing',
      (tester) async {
        final device = PreviewContacts();
        final c = ContactsController(device, device.directory);
        await Future.wait([c.loadDevice(), c.loadDirectory()]);
        final home = _Home();
        final dialer = _Dialer();
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contactsSharedFlowEnabledProvider.overrideWithValue(true),
              contactsControllerProvider.overrideWith((ref) => c),
              homeRepositoryProvider.overrideWithValue(home),
              systemDialerProvider.overrideWithValue(dialer),
            ],
            child: MaterialApp(
              navigatorKey: navigator,
              theme: ThemeData(platform: platform),
              home: const Scaffold(body: ContactsRoute()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
        await tester.pumpAndSettle();
        final detail = tester.widget<ContactDetailPage>(
          find.byType(ContactDetailPage),
        );
        await tester.tap(find.text('发起任务'));
        await tester.pumpAndSettle();
        expect(find.text('获取可用 Skill 失败，请重试'), findsOneWidget);
        expect(find.text('暂无可用 Skill'), findsNothing);
        home.fail = false;
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(find.text('合成可用技能'), findsOneWidget);
        expect(home.calls, 2);
        final sheet = tester.widget<ContactSkillsSheet>(
          find.byType(ContactSkillsSheet),
        );
        sheet.onClose();
        await tester.pumpAndSettle();
        navigator.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('覆盖页面'))),
        );
        await tester.pumpAndSettle();
        detail.onCall();
        detail.onTask();
        detail.onRetry();
        await tester.pumpAndSettle();
        expect(dialer.calls, 0);
        expect(home.calls, 2);
        expect(find.text('覆盖页面'), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('返回联系人'));
        await tester.pumpAndSettle();
        detail.onCall();
        detail.onTask();
        detail.onRetry();
        await tester.pumpAndSettle();
        expect(dialer.calls, 0);
        expect(home.calls, 2);
        expect(find.byType(ContactDetailPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
