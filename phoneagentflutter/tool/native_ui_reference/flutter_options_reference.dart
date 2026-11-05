import 'package:flutter/material.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_options_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';

class FlutterOptionsReference extends StatefulWidget {
  const FlutterOptionsReference({super.key});
  @override
  State<FlutterOptionsReference> createState() => _OptionsState();
}

class _OptionsState extends State<FlutterOptionsReference> {
  int? _selected;
  int _generation = 0;
  int _callbacks = 0;
  int _hiddenRevision = 0;
  double _rating = 4.7;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox.expand(
      child: NativeConversationBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 200, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConversationOptionsCard(
                  key: ValueKey(_generation),
                  message: ConversationMessage(
                    id: 'synthetic-options',
                    role: MessageRole.assistant,
                    text: '请选择合成候选',
                    options: ConversationMessages.options({
                      'items': [
                        {
                          'label': '合成餐厅',
                          'category': 'restaurant',
                          'rating': _rating,
                          'phone': 'synthetic-hidden-$_hiddenRevision',
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
                  enabled: true,
                  onSelect: (index) {
                    setState(() {
                      _selected = index;
                      _callbacks++;
                    });
                    return true;
                  },
                ),
                Text(
                  '合成已选：${_selected == null ? '无' : '第 ${_selected! + 1} 个'}',
                ),
                Text('合成回调：$_callbacks；隐藏版本：$_hiddenRevision'),
                TextButton(
                  onPressed: () => setState(() => _hiddenRevision++),
                  child: const Text('更新隐藏信息'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _rating = _rating == 4.7 ? 4.8 : 4.7;
                    _selected = null;
                  }),
                  child: const Text('更新合成评分'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selected = null;
                    _generation++;
                    _rating = 4.7;
                    _callbacks = 0;
                    _hiddenRevision = 0;
                  }),
                  child: const Text('重置候选示例'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
