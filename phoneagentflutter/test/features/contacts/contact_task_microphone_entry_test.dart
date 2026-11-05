import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_actions.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_task_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_skills_sheet.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../support/shell_fakes.dart';
import '../../support/pump_ui_transitions.dart';
import '../home/task_microphone_entry_test.dart' show EntryPermissions;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final late in [false, true]) {
      testWidgets('$platform contact task gates microphone, late=$late', (
        tester,
      ) async {
        final permissions = EntryPermissions();
        if (late) permissions.pending = Completer<PermissionGrant>();
        final epoch = StateProvider<int>((_) => 1);
        final container = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
            conversationPermissionSourceProvider.overrideWithValue(permissions),
            homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
            networkAvailabilitySourceProvider.overrideWithValue(
              const UnknownNetworkAvailability(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('发起任务'),
                    onPressed: () => showContactSkills(
                      context,
                      const ContactRecord(
                        name: '合成联系人',
                        phone: '2025550101',
                        systemDialPhone: '2025550101',
                      ),
                      preview: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('发起任务'));
        await tester.pumpUntilUiSettled();
        final sheet = tester.widget<ContactSkillsSheet>(
          find.byType(ContactSkillsSheet),
        );
        sheet.onSelect(
          sheet.cards.firstWhere(
            (card) => card.skillId == 'restaurant_booking',
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(find.byType(ContactTaskRoute), findsNothing);
        expect(permissions.requests, [false, true]);
        if (late) {
          container.read(epoch.notifier).state++;
          permissions.pending!.complete(PermissionGrant.granted);
          await tester.pumpUntilUiSettled();
          expect(find.byType(ContactTaskRoute), findsNothing);
        }
        expect(find.text('发起任务'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
