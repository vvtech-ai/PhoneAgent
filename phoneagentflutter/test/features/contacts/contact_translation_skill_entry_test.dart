import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contact_skills_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_actions.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_task_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_route.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/presentation/controller/online_entry_controller.dart';

HomeCard _translation(HomeCardStatus status) => HomeCard(
  id: 'translation',
  title: '同声传译',
  subtitle: '实时翻译通话',
  status: status,
  action: HomeAction.translation,
  minimumVersion: '99.0.0',
);

void main() {
  for (final status in [HomeCardStatus.enabled, HomeCardStatus.comingSoon]) {
    test('contact translation remains available for $status', () async {
      final version = _Version();
      final controller = ContactSkillsController(
        _Home(_translation(status)),
        version,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.cards, hasLength(1));
      expect(controller.state.cards.single.title, '实时翻译');
      expect(controller.state.cards.single.action, HomeAction.translation);
      expect(version.reads, 0);
    });
  }

  test('disabled contact translation remains hidden', () async {
    final controller = ContactSkillsController(
      _Home(_translation(HomeCardStatus.disabled)),
      _Version(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.state.cards, isEmpty);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform contact translation opens prefilled dialer', (
      tester,
    ) async {
      final card = _translation(HomeCardStatus.comingSoon);
      final admission = OnlineEntryController(
        const UnknownNetworkAvailability(),
        () => false,
      );
      addTearDown(admission.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeRepositoryProvider.overrideWithValue(_Home(card)),
            onlineEntryControllerProvider.overrideWithValue(admission),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showContactSkills(
                    context,
                    const ContactRecord(
                      name: '合成联系人',
                      phone: '2025550101',
                      systemDialPhone: '2025550101',
                    ),
                    preview: true,
                  ),
                  child: const Text('打开技能'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开技能'));
      await tester.pumpAndSettle();
      // Exercise navigation independently of the directory filtering test.
      tester
          .widget<ContactSkillsSheet>(find.byType(ContactSkillsSheet))
          .onSelect(card);
      await tester.pumpAndSettle();
      expect(find.byType(ContactTaskRoute), findsNothing);
      expect(find.byType(DialerRoute), findsOneWidget);
      final dialer = tester.widget<DialerRoute>(find.byType(DialerRoute));
      expect(dialer.number, '2025550101');
      expect(dialer.name, '合成联系人');
      expect(dialer.translationEntry, isTrue);
      expect(dialer.preview, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Home implements HomeRepository {
  const _Home(this.card);
  final HomeCard card;
  @override
  Future<HomeConfig> load() async =>
      HomeConfig('synthetic', const [HomeSlogan('s', '合成标题', '合成副标题')], [card]);
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async =>
      config.slogans.first;
}

class _Version implements InstalledAppSource {
  int reads = 0;
  @override
  Future<InstalledApp> read() async {
    reads++;
    return const InstalledApp('com.synthetic.test', '1.0.0', 1);
  }
}
