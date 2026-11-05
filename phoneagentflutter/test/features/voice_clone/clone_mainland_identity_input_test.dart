import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_enrollment_steps.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    Future<Finder> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CloneIdentityStep(busy: false, onSubmit: (_, _) {}),
            ),
          ),
        ),
      );
      return find.byType(TextField).last;
    }

    testWidgets('$platform mainland identity rejects illegal edits', (
      tester,
    ) async {
      final number = await open(tester);
      await tester.enterText(number, '000000');
      for (final input in [
        'E12345678',
        '000000X',
        '000000-',
        '００００００',
        '000000a',
        '000 000',
        '000000\r1',
        '000000\t1',
      ]) {
        await tester.enterText(number, input);
        expect(
          tester.widget<TextField>(number).controller!.text,
          '000000',
          reason: 'Illegal edit must preserve the previous prefix: $input',
        );
      }
    });

    testWidgets('$platform mainland identity normalizes paste and deletion', (
      tester,
    ) async {
      final number = await open(tester);
      for (final entry in <String, String>{
        ' 00000020000101003x ': '00000020000101003X',
        '0000002000010100059': '000000200001010005',
        '000000200001010005invalid': '000000200001010005',
        // Flutter 单行输入先移除换行，业务规则校验收到的 ASCII 文本。
        '000000\n1': '0000001',
        '00000': '00000',
        '': '',
      }.entries) {
        await tester.enterText(number, entry.key);
        expect(tester.widget<TextField>(number).controller!.text, entry.value);
      }
    });

    testWidgets('$platform mainland identity supports middle edits and caret', (
      tester,
    ) async {
      final number = await open(tester);
      await tester.enterText(number, '000000');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '0010000',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      final accepted = tester.widget<TextField>(number).controller!.value;
      expect(accepted.text, '0010000');
      expect(accepted.selection.baseOffset, 3);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '001X0000',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.pump();
      expect(tester.widget<TextField>(number).controller!.value, accepted);
    });

    testWidgets('$platform mainland identity presents ASCII input guidance', (
      tester,
    ) async {
      final number = await open(tester);
      final field = tester.widget<TextField>(number);
      expect(field.decoration!.hintText, '请输入18位大陆身份证号');
      expect(field.keyboardType, TextInputType.visiblePassword);
      expect(field.autocorrect, false);
      expect(field.enableSuggestions, false);
      expect(field.obscureText, false);
    });
  }

  test('mainland identity raw normalization rejects internal whitespace', () {
    for (final input in ['000000\n1', '000000\r1', '000000\t1', '000 0001']) {
      expect(normalizeCloneIdentityInput(input, '000000'), '000000');
    }
  });

  test(
    'mainland identity submission still checks birth date and check digit',
    () {
      expect(validCloneIdentityNumber('000000200001010005'), true);
      expect(validCloneIdentityNumber('00000020000101003x'), true);
      expect(validCloneIdentityNumber('000000200002300005'), false);
      expect(validCloneIdentityNumber('000000200001010006'), false);
      expect(validCloneIdentityNumber('00000020000101000'), false);
    },
  );
}
