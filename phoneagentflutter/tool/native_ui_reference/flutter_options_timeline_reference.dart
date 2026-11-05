import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';

/// Actual production page/scroll state; synthetic in-memory facts and no IO.
class FlutterOptionsTimelineReference extends StatefulWidget {
  const FlutterOptionsTimelineReference({super.key});
  @override
  State<FlutterOptionsTimelineReference> createState() => _TimelineState();
}

class _TimelineState extends State<FlutterOptionsTimelineReference> {
  final _page = GlobalKey();
  int _hidden = 0;
  double _rating = 4.7;
  String _result = '合成检查准备中';
  bool _running = false;

  ConversationState get _state => ConversationState(
    entry: const ConversationEntry(sessionId: 'synthetic-options-timeline'),
    activeOptionsId: 'synthetic-options',
    messages: [
      for (var i = 0; i < 30; i++)
        ConversationMessage(
          id: 'history-$i',
          role: MessageRole.assistant,
          text: '合成历史第 $i 条，仅验证会话滚动。',
        ),
      ConversationMessage(
        id: 'synthetic-options',
        role: MessageRole.assistant,
        text: '请选择合成候选',
        options: ConversationMessages.options({
          'items': [
            {
              'label': '合成餐厅',
              'category': 'restaurant',
              'rating': _rating,
              'phone': 'synthetic-hidden-$_hidden',
              'averageCostYuan': 88,
              'cuisine': '粤菜',
              'businessArea': '合成商圈',
              'distanceMeters': 1250,
              'openingStatus': 'OPEN',
              'openingHoursToday': '10:00–22:00',
            },
            {'label': '合成未营业餐厅', 'openingStatus': 'CLOSED'},
          ],
        }),
      ),
    ],
  );

  ScrollPosition _position() {
    ScrollPosition? result;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.position.axis == Axis.vertical) result ??= state.position;
      }
      element.visitChildren(visit);
    }

    final context = _page.currentContext;
    if (context is! Element) throw StateError('Synthetic page unavailable');
    visit(context);
    if (result == null) throw StateError('Synthetic timeline unavailable');
    return result!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_running || !mounted) return;
    _running = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final position = _position();
      position.jumpTo(
        (position.minScrollExtent + 220).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final before = _position().pixels;
      setState(() => _hidden++);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final hidden = _position().pixels;
      setState(() => _rating = _rating == 4.7 ? 4.8 : 4.7);
      // A busy simulator may deliver animation frames after a wall-clock
      // delay. Measure the actual scroll activity after the layout frame.
      await WidgetsBinding.instance.endOfFrame;
      var settled = false;
      for (var attempt = 0; attempt < 50 && mounted; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!_position().isScrollingNotifier.value) {
          settled = true;
          break;
        }
      }
      if (!settled) throw TimeoutException('Synthetic scroll did not settle');
      if (!mounted) return;
      final visible = _position().pixels;
      final success =
          before > 100 &&
          (hidden - before).abs() < .5 &&
          (visible - _position().minScrollExtent).abs() < .5;
      final report = {
        'success': success,
        'historyOffset': before,
        'hiddenUpdateOffset': hidden,
        'visibleUpdateOffset': visible,
        'platform': Theme.of(context).platform.name,
        'fixture': 'actual-production-page/same-message-id/synthetic-only',
      };
      debugPrint('SYNTHETIC_OPTIONS_TIMELINE ${jsonEncode(report)}');
      setState(
        () => _result =
            '${success ? '合成检查通过' : '合成检查失败'}\n'
            '历史 ${before.toStringAsFixed(1)} / 隐藏 ${hidden.toStringAsFixed(1)}'
            ' / 评分 ${visible.toStringAsFixed(1)}',
      );
    } catch (error) {
      if (mounted) setState(() => _result = '合成检查失败：${error.runtimeType}');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativeConversationBackground(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ConversationPage(
                key: _page,
                state: _state,
                modelName: '合成模型',
                onClose: () {},
                onToggle: () {},
                onSend: (_) => false,
                onChoose: (_, _) => true,
                onRetry: () {},
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
            Text(_result, key: const ValueKey('synthetic-timeline-result')),
            TextButton(
              onPressed: _running ? null : _check,
              child: const Text('重新运行合成滚动检查'),
            ),
          ],
        ),
      ),
    ),
  );
}
