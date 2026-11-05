import 'package:flutter/material.dart';
import '../../../../core/design/native_action_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/invite_providers.dart';
import '../../domain/invite.dart';
import '../controller/invite_controller.dart';
import '../pages/invite_page.dart';
import 'invite_rules_sheet.dart';
import 'invite_single_line_text.dart';

const inviteBlue = Color(0xFF276EF1);
const inviteMuted = Color(0xFF8A8F98);

class InviteActivitySection extends ConsumerWidget {
  const InviteActivitySection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inviteControllerProvider);
    final controller = ref.read(inviteControllerProvider.notifier);
    void open(Widget page) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UncontrolledProviderScope(
          container: ProviderScope.containerOf(context),
          child: page,
        ),
      ),
    );
    return InviteActivityCard(
      state: state,
      onRefresh: controller.refresh,
      onRules: () => showInviteRules(context, state.overview!.activity!),
      onPoster: controller.canShare ? () => open(const InvitePage()) : null,
    );
  }
}

class InviteActivityCard extends StatelessWidget {
  const InviteActivityCard({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onRules,
    this.onPoster,
    this.onRecords,
  });
  final InviteState state;
  final VoidCallback onRefresh, onRules;
  final VoidCallback? onPoster, onRecords;
  @override
  Widget build(BuildContext context) {
    final activity = state.overview?.activity;
    if (activity == null && !state.loading && state.error.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity?.name.isNotEmpty == true ? activity!.name : '邀请好友',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              TextButton(
                onPressed: activity == null ? null : onRules,
                style: TextButton.styleFrom(
                  foregroundColor: inviteBlue,
                  padding: EdgeInsets.zero,
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
                child: const Text('活动规则 ›'),
              ),
            ],
          ),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(color: inviteBlue),
            ),
          if (activity != null) ...[
            Text(
              activity.subtitle.isNotEmpty
                  ? activity.subtitle
                  : '邀请好友注册 Phone Agent\n${state.overview!.personal?.eligible == true && state.overview!.personal!.inviterPoints > 0 ? '你得 ${state.overview!.personal!.inviterPoints} 积分' : state.overview!.inviterLabel}，好友得 ${activity.inviteePoints} 积分',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: inviteMuted,
              ),
            ),
            const SizedBox(height: 16),
            _InviteSlots(activity: activity, state: state),
            if (activity.quota > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '左右滑动查看全部 ${activity.quota} 个名额',
                  style: const TextStyle(fontSize: 11, color: inviteMuted),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InviteSingleLineText(
                '已邀请 ${state.overview?.personal?.successful ?? '—'}/${activity.quota} 位'
                '${state.overview?.bonusLabel == null ? '' : ' · ${state.overview!.bonusLabel}'}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
          ],
          if (state.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.error,
                      style: const TextStyle(fontSize: 12, color: inviteMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: state.loading ? null : onRefresh,
                    child: const Text('刷新'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          InvitePrimaryAction(label: '邀请好友', onPressed: onPoster),
          if (onRecords != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: onRecords,
                style: TextButton.styleFrom(foregroundColor: inviteBlue),
                child: const Text(
                  '邀请记录',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteSlots extends StatelessWidget {
  const _InviteSlots({required this.activity, required this.state});
  final InviteActivity activity;
  final InviteState state;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final completed =
          state.overview?.personal?.successful ?? state.code?.used ?? 0;
      final code = state.code;
      final reserved = code?.reserved ?? 0;
      final available = code?.available ?? 0;
      final scaled = MediaQuery.textScalerOf(context).scale(11);
      final width = ((constraints.maxWidth - 32) / 5).clamp(
        scaled * 3 + 8,
        double.infinity,
      );
      final height = 55 + scaled * 1.4;
      return SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: activity.quota.clamp(0, 10000),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final done = i < completed;
            final pending = !done && code != null && i < completed + reserved;
            final free =
                !done &&
                !pending &&
                code != null &&
                i < completed + reserved + available;
            final next = free && i == completed + reserved;
            final color = done
                ? const Color(0xFF08A357)
                : next
                ? inviteBlue
                : const Color(0xFF7A8594);
            return Semantics(
              label:
                  '名额${i + 1}，${done
                      ? '已完成'
                      : pending
                      ? '待确认'
                      : free
                      ? '未邀请'
                      : '待同步'}',
              child: Container(
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: next ? 1 : .18),
                  ),
                  color: done
                      ? const Color(0xFFEFF8F3)
                      : next
                      ? const Color(0xFFF0F5FF)
                      : const Color(0xFFF7F8FA),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: done || next ? 1 : .12),
                      ),
                      child: Text(
                        done ? '✓' : '${i + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: done || next ? Colors.white : color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Text(
                        done
                            ? '已完成'
                            : pending
                            ? '待确认'
                            : free
                            ? '未邀请'
                            : '待同步',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class InvitePrimaryAction extends StatelessWidget {
  const InvitePrimaryAction({
    super.key,
    required this.label,
    this.onPressed,
    this.background,
    this.foreground = Colors.white,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? background;
  final Color foreground;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: NativeActionStyle.decoration(
      enabled: onPressed != null,
      backgroundColor: background,
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: NativeActionStyle.buttonStyle(context, foregroundColor: foreground)
          .copyWith(
            minimumSize: const WidgetStatePropertyAll(
              Size(double.infinity, 50),
            ),
          ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
