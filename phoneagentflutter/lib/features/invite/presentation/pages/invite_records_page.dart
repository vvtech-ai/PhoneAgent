import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../domain/invite_entry_presentation.dart';
import '../controller/invite_records_controller.dart';
import '../widgets/invite_activity_card.dart' show inviteBlue, inviteMuted;

class InviteRecordsPage extends StatelessWidget {
  const InviteRecordsPage({
    super.key,
    required this.state,
    required this.quota,
    required this.onBack,
    required this.onRefresh,
    required this.onLoadNext,
  });
  final InviteRecordsState state;
  final int quota;
  final VoidCallback onBack, onLoadNext;
  final Future<void> Function() onRefresh;
  Widget _error(VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state.error,
          style: const TextStyle(color: inviteMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: retry,
          child: const Text('重试', style: TextStyle(color: inviteBlue)),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      NativePageHeader(title: '邀请记录', onBack: onBack),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '本期邀请记录',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '好友完成有效注册后，奖励将显示在这里',
                            style: TextStyle(fontSize: 12, color: inviteMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${state.total}/$quota',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: inviteBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE8EBF0)),
                Expanded(
                  child: state.items.isEmpty
                      ? state.loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: inviteBlue,
                                  strokeWidth: 2,
                                ),
                              )
                            : state.error.isNotEmpty
                            ? Align(
                                alignment: Alignment.topCenter,
                                child: _error(() => onRefresh()),
                              )
                            : const Center(
                                child: Text(
                                  '本期暂无邀请记录',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: inviteMuted,
                                  ),
                                ),
                              )
                      : RefreshIndicator(
                          onRefresh: onRefresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              for (final row in state.items) ...[
                                Padding(
                                  key: ValueKey('invite-record-${row.id}'),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              row.maskedPhone,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF20242A),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              inviteRecordTime(
                                                row.registeredAt,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: inviteMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '+${row.points}积分',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF08A357),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            row.credited ? '已到账' : '到账中',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: inviteMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE8EBF0),
                                ),
                              ],
                              if (state.cursor != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: TextButton(
                                    onPressed: state.loadingNext
                                        ? null
                                        : onLoadNext,
                                    child: Text(
                                      state.loadingNext ? '加载中...' : '加载更多',
                                      style: const TextStyle(color: inviteBlue),
                                    ),
                                  ),
                                ),
                              if (state.error.isNotEmpty) _error(onLoadNext),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
