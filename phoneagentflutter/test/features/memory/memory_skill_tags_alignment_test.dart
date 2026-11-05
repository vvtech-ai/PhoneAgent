import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/widgets/memory_skill_tags.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final width in [160.0, 320.0, 430.0]) {
      for (final enabled in [true, false]) {
        testWidgets('tags center scale=$scale width=$width enabled=$enabled', (
          tester,
        ) async {
          var opens = 0;
          final removed = <String?>[];
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemorySkillTags(
                            scope: MemoryScope.selected,
                            ids: const {'meeting'},
                            skills: const [
                              MemorySkill('meeting', '会议邀请', true),
                            ],
                            enabled: enabled,
                            onRemove: removed.add,
                            onOpen: () => opens++,
                          ),
                          const Padding(
                            key: Key('legacy-memory-add'),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text('＋ 添加', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final tag = tester.getRect(
            find
                .ancestor(
                  of: find.text('会议邀请'),
                  matching: find.byType(Container),
                )
                .first,
          );
          final add = tester.getRect(
            find.byKey(const Key('memory-open-skills')),
          );
          expect(tag.height, closeTo(add.height, .01));
          final legacy = tester.getRect(
            find.byKey(const Key('legacy-memory-add')),
          );
          expect(add.height, closeTo(legacy.height, .01));
          final tagText = tester.getRect(find.text('会议邀请'));
          final addText = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('memory-open-skills')),
              matching: find.text('＋ 添加'),
            ),
          );
          expect(tagText.center.dy, closeTo(tag.center.dy, .01));
          expect(addText.center.dy, closeTo(add.center.dy, .01));
          expect(tagText.top, greaterThanOrEqualTo(tag.top));
          expect(tagText.bottom, lessThanOrEqualTo(tag.bottom));
          if (width == 430 || width == 320 && scale == 1) {
            expect(tag.center.dy, closeTo(add.center.dy, .01));
          } else {
            expect(add.top, greaterThanOrEqualTo(tag.bottom + 8));
          }
          await tester.tap(find.byKey(const Key('memory-open-skills')));
          expect(opens, enabled ? 1 : 0);
          await tester.tap(find.byTooltip('移除会议邀请标签'));
          expect(removed, enabled ? ['meeting'] : isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
