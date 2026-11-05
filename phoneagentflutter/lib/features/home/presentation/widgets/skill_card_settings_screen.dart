import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../domain/home_config.dart';
import '../../domain/home_card_preferences.dart';
import 'skill_card_setting_row.dart';

class SkillCardSettingsScreen extends StatelessWidget {
  const SkillCardSettingsScreen({
    super.key,
    required this.cards,
    required this.preferences,
    required this.ready,
    required this.readFailed,
    required this.notice,
    required this.onBack,
    required this.onRetry,
    required this.onVisible,
    required this.onReorder,
    required this.onRestore,
  });
  final List<HomeCard> cards;
  final HomeCardPreferences preferences;
  final bool ready, readFailed;
  final String notice;
  final VoidCallback onBack, onRetry, onRestore;
  final void Function(String, bool) onVisible;
  final void Function(int, int) onReorder;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FB),
    body: SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              NativePageHeader(title: 'Skill 卡片', onBack: onBack),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Text(
                    '拖动以调整首页显示的卡片的顺序',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8B919D)),
                  ),
                ),
              ),
              if (!ready)
                const Padding(padding: EdgeInsets.all(24), child: Text('加载中…')),
              if (notice.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ),
                      if (readFailed)
                        TextButton(onPressed: onRetry, child: const Text('重试')),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 76),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: Colors.white,
                      child: ReorderableListView.builder(
                        key: const Key('skill-card-list'),
                        padding: EdgeInsets.zero,
                        buildDefaultDragHandles: false,
                        itemCount: cards.length,
                        proxyDecorator: (child, index, animation) => Material(
                          elevation: 8,
                          color: Colors.white,
                          child: child,
                        ),
                        onReorder: onReorder,
                        itemBuilder: (context, index) => SkillCardSettingRow(
                          key: ValueKey(cards[index].id),
                          card: cards[index],
                          index: index,
                          enabled: ready,
                          visible: HomeCardPreferencePolicy.visible(
                            cards[index],
                            preferences,
                          ),
                          onVisible: (value) =>
                              onVisible(cards[index].id, value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: TextButton(
              key: const Key('skill-restore'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: ready ? onRestore : null,
              child: const Text(
                '恢复默认',
                style: TextStyle(
                  color: Color(0xFF1473FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
