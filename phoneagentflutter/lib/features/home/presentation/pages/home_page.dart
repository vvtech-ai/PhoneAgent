import 'package:flutter/material.dart';
import '../../../../core/design/native_navigation_backdrop.dart';
import '../../../../core/design/native_card_style.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/home_config.dart';
import '../controller/home_controller.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_card_illustration.dart';
import '../widgets/home_card_extent.dart';
import '../../../points/presentation/widgets/points_balance_badge.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.modelName,
    required this.onModels,
    required this.onEntry,
    required this.onRefresh,
    this.pointsBalance,
    this.onPoints,
    this.onWelfare,
    this.notification,
    this.modelMultiplier,
    this.visibleCards,
    this.installedVersion = '',
    this.onCardPreferences,
  });
  final HomeState state;
  final String modelName;
  final VoidCallback onModels;
  final ValueChanged<HomeCard> onEntry;
  final Future<void> Function() onRefresh;
  final int? pointsBalance;
  final VoidCallback? onPoints;
  final VoidCallback? onWelfare;
  final Widget? notification;
  final double? modelMultiplier;
  final List<HomeCard>? visibleCards;
  final String installedVersion;
  final VoidCallback? onCardPreferences;

  @override
  Widget build(BuildContext context) {
    final slogan = state.slogan ?? state.config.slogans.first;
    final cards = (visibleCards ?? state.config.cards)
        .where(
          (c) =>
              c.status != HomeCardStatus.disabled &&
              (visibleCards != null || c.defaultVisible),
        )
        .toList();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'PhoneAgent',
                  style: ShellTokens.homeTitle(context),
                ),
              ),
              if (onCardPreferences != null)
                IconButton(
                  onPressed: onCardPreferences,
                  tooltip: '管理首页技能卡片',
                  icon: const Icon(Icons.tune_rounded),
                ),
              if (onPoints != null) ...[
                const SizedBox(width: 8),
                PointsBalanceBadge(balance: pointsBalance, onOpen: onPoints!),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text('电话智能体 - 你的语音分身', style: ShellTokens.subtitle),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollHeader =
            constraints.maxHeight -
                    NativeNavigationBackdrop.viewportInsetOf(context) <
                700 &&
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final scroll = RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            key: const PageStorageKey('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (scrollHeader) SliverToBoxAdapter(child: header),
              if (scrollHeader && notification != null)
                SliverToBoxAdapter(child: notification),
              SliverToBoxAdapter(
                child: HomeHero(
                  slogan: slogan,
                  modelName: modelName,
                  modelMultiplier: modelMultiplier,
                  onModels: onModels,
                  onWelfare: onWelfare,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final height = homeCardExtent(
                      context,
                      gridWidth: constraints.crossAxisExtent,
                      cards: cards,
                    );
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _SkillCard(
                          card: cards[index],
                          installedVersion: installedVersion,
                          onTap: () => onEntry(cards[index]),
                        ),
                        childCount: cards.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: height.toDouble(),
                      ),
                    );
                  },
                ),
              ),
              if (state.loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      16 + NativeNavigationBackdrop.homeContentInsetOf(context),
                ),
              ),
            ],
          ),
        );
        return scrollHeader
            ? scroll
            : Column(
                children: [
                  header,
                  if (notification != null) notification!,
                  Expanded(child: scroll),
                ],
              );
      },
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.card,
    required this.onTap,
    required this.installedVersion,
  });
  final HomeCard card;
  final String installedVersion;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final enabled = card.canEnter(installedVersion);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        decoration: NativeCardStyle.decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('skill-${card.id}'),
            onTap: enabled ? onTap : null,
            child: Stack(
              children: [
                Positioned(
                  right: -2,
                  bottom: -2,
                  width: 82,
                  height: 82,
                  child: HomeCardIllustration(
                    cardId: card.id,
                    url: card.imageUrl,
                    enabled: enabled,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: !enabled
                                  ? const Color(0xFFC7C7CC)
                                  : card.action == HomeAction.translation
                                  ? const Color(0xFF7865F9)
                                  : ShellTokens.accent,
                            ),
                          ),
                          const Spacer(),
                          if (!enabled)
                            Flexible(
                              child: Text(
                                card.supports(installedVersion)
                                    ? '即将提供'
                                    : '请升级客户端',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ShellTokens.muted,
                                ),
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        card.title,
                        style: ShellTokens.cardTitle.copyWith(
                          color: enabled
                              ? const Color(0xFF121826)
                              : const Color(0xFF8E8E93),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          card.subtitle,
                          style: ShellTokens.cardSubtitle.copyWith(
                            color: enabled
                                ? ShellTokens.muted
                                : const Color(0xFFA3A3AA),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
