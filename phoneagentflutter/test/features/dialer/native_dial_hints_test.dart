import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_contacts.dart';
import 'package:phone_agent/features/dialer/domain/dial_contact_suggestion.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_contacts_controller.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_recent_controller.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_contact_suggestions.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_recent_list.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'native contacts silently empty for unreadable or unmatched $platform',
      (tester) async {
        for (final state in const [
          DialContactsState(loading: true),
          DialContactsState(failed: true),
          DialContactsState(access: ContactAccess.denied),
          DialContactsState(access: ContactAccess.unsupported),
          DialContactsState(access: ContactAccess.authorized),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: DialContactSuggestions(
                  query: '97',
                  state: state,
                  nativeLayout: true,
                  onSelect: (_) => fail('No result'),
                  onRetry: () {},
                ),
              ),
            ),
          );
          expect(find.byType(Text), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      'native history empty uses original without source diagnostics $platform',
      (tester) async {
        for (final access in DialRecentAccess.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: DialRecentList(
                  nativeLayout: true,
                  state: DialRecentState(
                    system: DialRecentSnapshot(access),
                    app: DialRecentSnapshot(access),
                  ),
                  onSelect: (_) => fail('No result'),
                  onRetry: () {},
                ),
              ),
            ),
          );
          expect(find.text('暂无通话记录'), findsOneWidget);
          expect(find.byType(Text), findsOneWidget);
        }
      },
    );
    testWidgets(
      'native contact match retains highlight and local selection $platform',
      (tester) async {
        final snapshot = await PreviewDialContacts().load();
        final entries = const DialSuggestionPolicy(
          LpinyinContactDictionary(),
        ).index(snapshot.rows);
        DialContactSuggestion? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DialContactSuggestions(
                  query: '202',
                  state: DialContactsState(
                    entries: entries,
                    access: ContactAccess.authorized,
                  ),
                  nativeLayout: true,
                  onSelect: (value) => selected = value,
                  onRetry: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(const Key('dial-suggestions')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('dial-suggestion:0')));
        expect(selected, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
