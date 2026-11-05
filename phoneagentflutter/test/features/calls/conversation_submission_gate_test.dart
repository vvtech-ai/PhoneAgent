import 'dart:async';
import '../../support/confirm_rendered_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _BalanceFlow extends PreviewCallFlow {
  _BalanceFlow() : super(CallFlowScenario.insufficient);
  final refreshed = Completer<int?>();
  int refreshes = 0;
  @override
  CallAdmissionService get admission => _admission;
  late final _admission = CallAdmissionService(
    store: this,
    notices: this,
    readBalance: () => 0,
    readModel: () => '合成模型',
    refreshBalance: () {
      refreshes++;
      if (refreshes == 1) return Future.value(0);
      return refreshed.future;
    },
  );
}

ConversationController _controller(_BalanceFlow ports) {
  var id = 0;
  return ConversationController(
    entry: const ConversationEntry(sessionId: 'mock-gate'),
    accountId: 'synthetic',
    gateway: ports,
    history: ports,
    callAdmission: ports.admission,
    callSessions: ports,
    nextId: () => 'id-${id++}',
  );
}

Future<void> _firstNotice(WidgetTester tester, ConversationController c) async {
  expect(c.send('合成需求'), isTrue);
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  confirmRenderedCall(c);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  expect(c.state.phase, ConversationPhase.ready);
}

void main() {
  for (final balance in <int?>[10000, null]) {
    testWidgets(
      'refreshed balance $balance forwards original input only once',
      (tester) async {
        final ports = _BalanceFlow();
        final c = _controller(ports);
        addTearDown(c.dispose);
        await _firstNotice(tester, c);
        expect(c.send('修改需求，第二次修改需求，原始输入'), isTrue);
        expect(c.send('修改需求，不应并发发送'), isFalse);
        await tester.pump();
        expect(ports.commands.length, 1);
        expect(ports.refreshes, 2);
        ports.refreshed.complete(balance);
        await tester.pump();
        expect(ports.commands.length, 2);
        expect(ports.commands.last.message, '修改需求，第二次修改需求，原始输入');
        expect(ports.commands.last.actionId, isNull);
        expect(ports.noticePosts, 1);
        c.close();
      },
    );
  }
  testWidgets('still insufficient never sends or echoes the second input', (
    tester,
  ) async {
    final ports = _BalanceFlow();
    final c = _controller(ports);
    addTearDown(c.dispose);
    await _firstNotice(tester, c);
    c.send('修改需求，不应发给Agent');
    await tester.pump();
    ports.refreshed.complete(0);
    await tester.pump();
    expect(ports.commands.length, 1);
    expect(
      c.state.messages.where((m) => m.role.name == 'user').map((m) => m.text),
      ['合成需求', '确认拨打'],
    );
    expect(c.state.messages.where((m) => m.text == '修改需求，不应发给Agent'), isEmpty);
    expect(c.state.phase, ConversationPhase.ready);
    expect(
      c.calls!.snapshot.launch.decision!.kind.name,
      'repeatedInsufficient',
    );
    expect(ports.noticePosts, 1);
    c.close();
  });
  for (final action in ['close', 'restore']) {
    testWidgets('$action invalidates an in-flight balance admission', (
      tester,
    ) async {
      final ports = _BalanceFlow();
      final c = _controller(ports);
      addTearDown(c.dispose);
      await _firstNotice(tester, c);
      c.send('修改需求，晚到修改需求，不能发送');
      await tester.pump();
      if (action == 'close') {
        c.close();
      } else {
        await c.restore();
        markCallCardPresented(c);
      }
      ports.refreshed.complete(10000);
      await tester.pump(const Duration(seconds: 3));
      expect(ports.commands.length, 1);
      expect(ports.hangups, 0);
      c.close();
    });
  }
  testWidgets('refresh ownership failure never forwards the pending input', (
    tester,
  ) async {
    final ports = _BalanceFlow();
    final c = _controller(ports);
    addTearDown(c.dispose);
    await _firstNotice(tester, c);
    c.send('修改需求，不能发送');
    await tester.pump();
    ports.refreshed.completeError(StateError('synthetic owner changed'));
    await tester.pump();
    expect(ports.commands.length, 1);
    expect(c.state.phase, ConversationPhase.ready);
    expect(c.state.notice, contains('无法确认当前登录或积分状态'));
    c.close();
  });
}
