import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/design/shell_tokens.dart';

class FloatingNavigation extends StatelessWidget {
  const FloatingNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onDial,
    this.taskBadgeCount = 0,
  });
  final int selected, taskBadgeCount;
  final ValueChanged<int> onSelected;
  final VoidCallback onDial;

  static double contentInset(BuildContext context) {
    final font = MediaQuery.textScalerOf(context).scale(10);
    final iconHeight = font * 1.6 > 20 ? font * 1.6 : 20.0;
    // Label line, icon slot, gap, tab padding, surface padding and border.
    final required = iconHeight + font * 1.2 + 41;
    return (required > ShellTokens.navHeight
            ? required
            : ShellTokens.navHeight) +
        36;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _build);

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final compact = constraints.maxWidth < 338;
    final height = contentInset(context) - 36;
    return SizedBox(
      height: height + 36,
      child: Stack(
        children: [
          Positioned(
            left: compact ? 25 : 28,
            right: compact ? 25 : 28,
            bottom: 18,
            height: height,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              decoration: BoxDecoration(
                color: const Color(0xE6F8F8FA),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xD6FFFFFF)),
                boxShadow: const [ShellTokens.softShadow],
              ),
              child: Row(
                children: [
                  _tab(context, 0, '首页', 3),
                  _tab(context, 1, '联系人', 4),
                  SizedBox(width: compact ? 60 : 72),
                  _tab(context, 2, '任务', 5),
                  _tab(context, 3, '设置', 6),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _dialButton()),
          ),
        ],
      ),
    );
  }

  Widget _dialButton() => Semantics(
    container: true,
    button: true,
    enabled: true,
    label: '打开拨号盘',
    onTap: onDial,
    excludeSemantics: true,
    child: SizedBox(
      width: 60,
      height: 60,
      child: Material(
        color: ShellTokens.accent,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: ShellTokens.accent.withValues(alpha: 0.3),
        child: InkWell(
          key: const ValueKey('assistantFab'),
          onTap: onDial,
          customBorder: const CircleBorder(),
          child: Semantics(
            label: '打开拨号盘',
            button: true,
            child: Center(
              child: SizedBox(
                width: 19,
                height: 25,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    3,
                    (_) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _tab(BuildContext context, int index, String label, int asset) {
    final badge = index == 2 ? taskBadgeCount : 0;
    final badgeHeight = MediaQuery.textScalerOf(context).scale(10) * 1.6;
    final iconHeight = badgeHeight > 20 ? badgeHeight : 20.0;
    final color = selected == index ? ShellTokens.accent : ShellTokens.muted;
    return Expanded(
      child: Semantics(
        container: true,
        selected: selected == index,
        button: true,
        enabled: true,
        label: badge > 0 ? '$label，$badge 条未读通知' : label,
        onTap: () => onSelected(index),
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('tab-$index'),
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: iconHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/shell/shell_$asset.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                      if (badge > 0)
                        Positioned(
                          right: -8,
                          top: -badgeHeight / 2 + 2,
                          child: Container(
                            key: const ValueKey('task-unread-badge'),
                            constraints: BoxConstraints(
                              minWidth: badgeHeight,
                              minHeight: badgeHeight,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(
                                badgeHeight / 2,
                              ),
                            ),
                            child: Text(
                              '${badge.clamp(1, 99)}',
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.6,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
