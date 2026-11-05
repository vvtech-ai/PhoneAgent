import 'dart:async';
import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_actions.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_task_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/presentation/controller/online_entry_controller.dart';

const _card = HomeCard(
  id: 'synthetic',
  title: '合成技能',
  subtitle: '合成说明',
  status: HomeCardStatus.enabled,
  action: HomeAction.skill,
  skillId: 'restaurant_booking',
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scenario in [
      'close_twice',
      'select_then_close',
      'epoch_before_return',
      'epoch_during_admission',
    ]) {
      testWidgets('$platform skill return guard $scenario', (tester) async {
        final epoch = StateProvider<int>((_) => 1);
        final delayed = _DelayedNetwork();
        final admission = OnlineEntryController(
          scenario == 'epoch_during_admission'
              ? delayed
              : const UnknownNetworkAvailability(),
          () => false,
        );
        addTearDown(admission.close);
        final container = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
            homeRepositoryProvider.overrideWithValue(_Home()),
            onlineEntryControllerProvider.overrideWithValue(admission),
          ],
        );
        addTearDown(container.dispose);
        final preview =
            scenario == 'close_twice' || scenario == 'select_then_close';
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('根页面'),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Builder(
                          builder: (detailContext) => Scaffold(
                            body: TextButton(
                              child: const Text('打开技能'),
                              onPressed: () => showContactSkills(
                                detailContext,
                                const ContactRecord(
                                  name: '合成联系人',
                                  phone: '2025550101',
                                  systemDialPhone: '2025550101',
                                ),
                                preview: preview,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('根页面'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('打开技能'));
        await tester.pumpAndSettle();
        final sheet = tester.widget<ContactSkillsSheet>(
          find.byType(ContactSkillsSheet),
        );
        if (scenario == 'close_twice') {
          sheet.onClose();
          sheet.onClose();
          await tester.pumpAndSettle();
          expect(find.text('打开技能'), findsOneWidget);
          sheet.onClose();
          await tester.pumpAndSettle();
          expect(find.text('打开技能'), findsOneWidget);
        } else if (scenario == 'select_then_close') {
          sheet.onSelect(_card);
          sheet.onClose();
          await tester.pumpUntilUiSettled();
          expect(find.byType(ContactTaskRoute), findsOneWidget);
          tester
              .widget<ConversationPage>(find.byType(ConversationPage))
              .onClose();
          await tester.pumpAndSettle();
          expect(find.text('打开技能'), findsOneWidget);
        } else {
          sheet.onSelect(_card);
          if (scenario == 'epoch_during_admission') {
            await tester.pump();
            expect(delayed.reads, 1);
          }
          container.read(epoch.notifier).state = 2;
          if (scenario == 'epoch_during_admission') {
            delayed.result.complete(NetworkAvailability.available);
          }
          await tester.pumpAndSettle();
          expect(find.byType(ContactTaskRoute), findsNothing);
          expect(find.text('打开技能'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _Home implements HomeRepository {
  @override
  Future<HomeConfig> load() async => const HomeConfig('1', [], [_card]);
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async =>
      const HomeSlogan('synthetic', '', '');
}

class _DelayedNetwork implements NetworkAvailabilitySource {
  int reads = 0;
  final result = Completer<NetworkAvailability>();
  @override
  Future<NetworkAvailability> read() {
    reads++;
    return result.future;
  }
}
