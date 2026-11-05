import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in ['empty', 'saved', 'loading', 'error']) {
      testWidgets(
        '$platform $mode hides all remarks and retains profile actions',
        (tester) async {
          var back = 0, call = 0, task = 0;
          final state = ContactsState(
            selected: const ContactRecord(
              name: '测试联系人',
              phone: '2025550101',
              systemDialPhone: '2025550101',
            ),
            directory: mode == 'saved'
                ? [
                    const ContactDirectoryEntry(
                      phone: '2025550101',
                      description: '保留的备注',
                    ),
                  ]
                : [],
            directoryLoading: mode == 'loading',
            directoryError: mode == 'error' ? '合成读取失败' : '',
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: ContactDetailPage(
                  state: state,
                  onBack: () => back++,
                  onCall: () => call++,
                  onTask: () => task++,
                  onEdit: () => fail('hidden edit'),
                  onDelete: () => fail('hidden delete'),
                  onRetry: () => fail('hidden retry'),
                ),
              ),
            ),
          );
          for (final text in [
            '备注',
            '用于 AI 参考的说明',
            '暂无备注',
            '备注加载中…',
            '合成读取失败',
            '保留的备注',
            '编辑',
            '删除',
            '重试备注',
          ]) {
            expect(find.text(text), findsNothing);
          }
          final children =
              (tester.widget<ListView>(find.byType(ListView)).childrenDelegate
                      as SliverChildListDelegate)
                  .children;
          expect((children.last as Text).data, '本机通讯录联系人');
          expect(find.text('测试联系人'), findsOneWidget);
          expect(find.text('2025550101'), findsOneWidget);
          await tester.tap(find.text('拨打电话'));
          await tester.tap(find.text('发起任务'));
          await tester.tap(find.bySemanticsLabel('返回联系人'));
          expect([back, call, task], [1, 1, 1]);
          expect(state.remark, mode == 'saved' ? '保留的备注' : '');
        },
      );
    }
  }
}
