import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/shell_tokens.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'package:phone_agent/features/identity/presentation/widgets/identity_widgets.dart';
import 'package:phone_agent/features/memory/presentation/widgets/memory_frame.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_record_card.dart';

void main() {
  final cases = <String, Widget>{
    '购买信息': const CommerceCard(child: Text('合成信息')),
    '身份信息': const IdentityCard(child: Text('合成信息')),
    '记忆': const MemoryCard(child: Text('合成信息')),
    '任务': TaskRecordCard(
      title: '合成信息',
      detail: '合成说明',
      status: '完成',
      statusColor: Colors.green,
      onTap: () {},
    ),
  };
  for (final entry in cases.entries) {
    testWidgets('${entry.key} uses D05 surface without changing navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 320, child: entry.value)),
        ),
      );
      final surfaces = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == const Color(0xCCFFFFFF));
      expect(surfaces, isNotEmpty);
      final surface = surfaces.first;
      expect(surface.borderRadius, BorderRadius.circular(24));
      expect(surface.border, Border.all(color: const Color(0xC7FFFFFF)));
      expect(surface.boxShadow, const [
        BoxShadow(
          color: Color(0x14101114),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ]);
      expect(ShellTokens.softShadow.blurRadius, 24);
      expect(ShellTokens.softShadow.offset, const Offset(0, 10));
      expect(tester.takeException(), isNull);
    });
  }
}
