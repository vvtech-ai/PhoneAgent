import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_model_card.dart';

void main() {
  testWidgets(
    'membership hint is visible without replacing supplier availability',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeModelCard(
              model: const CallModel(
                id: 'm',
                name: '测试模型',
                description: '',
                available: true,
                active: false,
              ),
              selected: false,
              busy: false,
              onSelect: () => selected++,
              membershipHint: '当前会员暂不支持此模型，需中级会员',
            ),
          ),
        ),
      );
      expect(find.textContaining('需中级会员'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('model-m')));
      expect(selected, 1); // The server remains authoritative after purchases.
    },
  );
}
