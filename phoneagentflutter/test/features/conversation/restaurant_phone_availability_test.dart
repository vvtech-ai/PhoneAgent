import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_options_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_option_values.dart';

Map<String, Object?> option([Object? available]) => {
  'id': 'opt_2',
  'label': '合成品牌（测试分店）',
  'address': '合成路一号',
  'category': 'restaurant',
  if (available != null) 'phoneAvailable': available,
};

ConversationMessage message([Object? available]) => ConversationMessage(
  id: 'choice',
  role: MessageRole.assistant,
  text: '请选择',
  options: ConversationMessages.options({
    'items': [option(available)],
  }),
);

void main() {
  test(
    'phone availability changes rendered revision without inferring legacy phones',
    () {
      expect(
        conversationOptionValues(message()),
        isNot(conversationOptionValues(message(false))),
      );
      expect(
        conversationOptionValues(message()),
        conversationOptionValues(message('true')),
      );
      expect(
        conversationOptionValues(message(true)),
        conversationOptionValues(message()),
      );
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform no-phone candidate is explained before selection at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final choices = <int>[];
          Future<void> render(
            ConversationMessage value, {
            bool enabled = true,
          }) => tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: ConversationOptionsCard(
                      message: value,
                      enabled: enabled,
                      onSelect: (index) {
                        choices.add(index);
                        return true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await render(message(false));
          expect(find.text('暂无可拨打电话'), findsOneWidget);
          expect(find.text('合成路一号'), findsOneWidget);
          expect(find.text('合成品牌（测试分店）'), findsOneWidget);
          expect(choices, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('option:choice:0')));
          expect(choices, [0]);
          await render(message(false), enabled: false);
          await tester.tap(find.byKey(const ValueKey('option:choice:0')));
          expect(choices, [0]);
          expect(find.text('暂无可拨打电话'), findsOneWidget);

          final restored = ConversationMessages.project([
            LedgerEvent(
              eventId: 'event-1',
              sessionId: 'session',
              sequence: 1,
              type: 'TOOL_REQUESTED',
              schemaVersion: 1,
              payload: {
                'toolName': 'showOptions',
                'toolCallId': 'choice',
                'displayPayloadVersion': 1,
                'arguments': {
                  'title': '请选择',
                  'optionsJson': [option(false)],
                },
              },
            ),
          ]).single;
          expect(
            conversationOptionValues(restored),
            conversationOptionValues(message(false)),
          );
          await render(restored, enabled: false);
          expect(find.text('暂无可拨打电话'), findsOneWidget);
          expect(find.text('合成路一号'), findsOneWidget);
          for (final availability in [null, true, 'false']) {
            await render(message(availability));
            expect(find.text('暂无可拨打电话'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
