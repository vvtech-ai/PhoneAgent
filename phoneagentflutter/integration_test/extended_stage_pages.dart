import '../test/support/pump_ui_transitions.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import '../tool/previews/shell_clone_ports.dart';
import '../tool/previews/shell_contacts_preview.dart';
import '../tool/previews/shell_receipt_preview.dart';
import '../tool/previews/shell_receipt_seeds.dart';

/// Device and VM execute exactly the same formal routes and assertions.
/// Caller owns the MOCK host; no native capability or saved account is read.
Future<void> verifyExtendedStagePages(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  Future<void> settled() async {
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(Finder target) async {
    await settled();
    if (target.evaluate().isEmpty) {
      final detail = find.descendant(
        of: find.byKey(const ValueKey('task-detail-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: detail.evaluate().isNotEmpty
            ? detail.first
            : find.byType(Scrollable).last,
      );
    }
    await Scrollable.ensureVisible(tester.element(target), alignment: .35);
    await settled();
    if (target.hitTestable().evaluate().isEmpty) {
      await Scrollable.ensureVisible(tester.element(target), alignment: .35);
      await settled();
    }
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await settled();
  }

  Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
  Future<void> text(String value) => tap(find.text(value));
  Future<void> input(Finder field, String value) async {
    await tester.enterText(field, value);
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await settled();
  }

  Future<void> back() => tap(
    find.byType(BackButton).evaluate().isNotEmpty
        ? find.byType(BackButton)
        : find.byTooltip('返回'),
  );

  await key('tab-1');
  await tap(find.bySemanticsLabel('演示联系人，2025550101'));
  await text('编辑');
  await input(find.byKey(const ValueKey('contact-remark-input')), '阶段合成备注');
  await text('保存');
  expect(find.text('阶段合成备注'), findsOneWidget);
  await capture('12-contact-remark');
  await tap(find.byTooltip('返回联系人'));
  await tap(find.bySemanticsLabel('演示联系人，2025550102'));
  expect(find.text('暂无备注'), findsOneWidget);
  await text('拨打电话');
  // Effective contact action hands off directly to the isolated system dialer.
  expect(container.read(shellContactsPortsProvider).openedNumbers, [
    '2025550102',
  ]);
  await capture('13-contact-dial');
  await tap(find.byTooltip('返回联系人'));

  await key('tab-2');
  await key('conversation:${ShellReceiptSeeds.singleSession}');
  expect(find.byTooltip('播放录音'), findsOneWidget);
  await tap(find.byTooltip('好评'));
  await capture('14-single-receipt');
  await text('去评分');
  for (final dimension in ['understanding', 'call', 'clone', 'completion']) {
    await key('rating-$dimension-4');
  }
  await tester.scrollUntilVisible(
    find.byType(TextFormField),
    160,
    scrollable: find
        .descendant(
          of: find.byType(TaskRatingSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await input(find.byType(TextFormField), '双端共享页面合成评分');
  await capture('15-rating-draft');
  await text('提交评价');
  expect(find.text('评价提交失败，请重试'), findsOneWidget);
  await text('提交评价');
  expect(find.text('评价提交成功'), findsOneWidget);
  final feedback = container.read(shellFeedbackPortsProvider);
  expect(feedback.submitKeys, hasLength(2));
  expect(feedback.submitKeys.toSet(), hasLength(1));
  await tap(find.widgetWithText(FilledButton, '完成'));
  await key('close-conversation');
  await key('conversation:${ShellReceiptSeeds.singleSession}');
  await text('查看');
  expect(find.text('查看评分'), findsOneWidget);
  expect(find.text('提交评价'), findsNothing);
  await capture('16-rating-readonly');
  await tap(find.byTooltip('关闭评分'));
  await key('close-conversation');
  await key('conversation:${ShellReceiptSeeds.batchSession}');
  expect(find.text('去评分'), findsNothing);
  await key('receipt-transcript:one');
  expect(find.text('确认参加会议。'), findsOneWidget);
  await capture('17-batch-receipt');
  await key('close-conversation');

  await key('tab-3');
  expect(find.byKey(const ValueKey('settings-identity')), findsNothing);
  await key('settings-models');
  await capture('18-clone-models');
  await text('声音克隆');
  await key('clone-create-QWEN_OMNI_PLUS');
  await tap(find.byType(CloneCheckRow));
  await text('开始认证');
  await text('填入合成测试数据');
  await text('开始人脸跟读认证');
  expect(find.text('声音克隆已完成'), findsOneWidget);
  await capture('19-clone-candidate');
  final save = find.byType(CloneCheckRow);
  if (!tester.widget<CloneCheckRow>(save).checked) await tap(save);
  await text('设为默认声音');
  // The workbench retains its explicit return; production returns automatically.
  await text('完成并返回');
  expect(find.text('声音克隆已完成'), findsNothing);
  final clone = container.read(cloneCreationPortProvider) as ShellClonePorts;
  expect(clone.catalog.cloneAssets, {'QWEN_OMNI_PLUS'});
  expect(clone.recording, isTrue);
  await key('voices-QWEN_OMNI_PLUS');
  expect(
    tester
        .widget<NativeVoiceSelectionRow>(
          find.byKey(const ValueKey('selectCloneVoice')),
        )
        .selected,
    isTrue,
  );
  await capture('20-clone-selected');
  await key('backFromVoiceIdentity');
  await key('backFromVoiceModel');

  await key('tab-0');
  // The earlier restaurant journey leaves the retained home list scrolled.
  // Wallet is in its header, so reveal upward rather than search downward.
  await tester.drag(
    find.byKey(const PageStorageKey('home-scroll')),
    const Offset(0, 900),
  );
  await settled();
  await key('open-points-wallet');
  expect(find.text('会员与积分'), findsOneWidget);
  await text('积分流水  ›');
  expect(find.byKey(const ValueKey('points-ledger-1')), findsOneWidget);
  await capture('21-wallet-ledger');
  await back();
  await back();
}
