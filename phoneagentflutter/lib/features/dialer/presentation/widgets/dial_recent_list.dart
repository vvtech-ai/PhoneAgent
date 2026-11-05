import 'package:flutter/material.dart';
import '../../domain/dial_contact_suggestion.dart';
import '../../domain/dial_phone_policy.dart';
import '../../domain/dial_recent_call.dart';
import '../../domain/dial_recent_source.dart';
import '../controller/dial_recent_controller.dart';

class DialRecentList extends StatelessWidget {
  const DialRecentList({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onRetry,
    this.enabled = true,
    this.nativeLayout = false,
  });
  final DialRecentState state;
  final ValueChanged<DialRecentCall> onSelect;
  final VoidCallback onRetry;
  final bool enabled, nativeLayout;

  @override
  Widget build(BuildContext context) {
    final records = state.records;
    if (nativeLayout) {
      if (records.isEmpty) {
        return state.loading
            ? const SizedBox.shrink()
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    '暂无通话记录',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              );
      }
      return ListView.builder(
        key: ValueKey('dial-history:${records.first.key}'),
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: records.length,
        itemBuilder: (_, index) => _RecentRow(
          record: records[index],
          onTap: enabled && records[index].selectable
              ? () => onSelect(records[index])
              : null,
        ),
      );
    }
    final failed = [
      state.system,
      state.app,
    ].any((s) => s.access == DialRecentAccess.failed);
    final notices = <String>[
      if (state.system.access == DialRecentAccess.denied) '未授权系统通话记录',
      if (state.system.access == DialRecentAccess.notConnected) '系统通话记录尚未接入',
      if (state.app.access == DialRecentAccess.notConnected) 'App通话记录归档尚未接入',
      if (state.app.access == DialRecentAccess.denied) 'App通话记录暂不可读取',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (state.loading) const LinearProgressIndicator(),
          if (!state.loading && notices.isNotEmpty)
            Text(
              notices.join('；'),
              key: const Key('dial-history-source-status'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          if (failed)
            TextButton(
              key: const Key('dial-recent-retry'),
              onPressed: state.loading || !enabled ? null : onRetry,
              child: const Text('部分通话记录读取失败，重试'),
            ),
          if (records.isEmpty && !state.loading && !failed && notices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                '暂无通话记录',
                style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ),
          if (records.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                key: ValueKey('dial-history:${records.first.key}'),
                primary: false,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: records.length,
                itemBuilder: (_, index) => _RecentRow(
                  record: records[index],
                  onTap: enabled && records[index].selectable
                      ? () => onSelect(records[index])
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record, this.onTap});
  final DialRecentCall record;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('dial-recent:${record.key}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      dialRecentTitle(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111318),
                      ),
                    ),
                  ),
                  if (record.kind == DialRecentKind.translation)
                    Container(
                      margin: const EdgeInsets.only(left: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x146C55ED),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        '实时翻译',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C55ED),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dialRecentNumber(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dialRecentTime(record.startedAtMillis, DateTime.now()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String dialRecentTitle(DialRecentCall record) {
  var value = record.name;
  for (final prefix in ['翻译通话 ', '实时翻译 ', '普通通话 ']) {
    if (value.startsWith(prefix)) value = value.substring(prefix.length);
  }
  return value.trim().isEmpty ? record.phone : value;
}

String dialRecentNumber(DialRecentCall record) {
  if (!record.selectable) return record.phone;
  final parts = DialSuggestionPolicy.numberParts(record.restorablePhone);
  if (parts.iso == null) return record.restorablePhone;
  return [
    parts.prefix,
    DialPhonePolicy.display(parts.digits, parts.iso!),
  ].where((s) => s.isNotEmpty).join(' ');
}

String dialRecentTime(int millis, DateTime now) {
  if (millis <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final sameYear = date.year == now.year;
  if (sameYear && date.month == now.month && date.day == now.day) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  // v65 retains M/d across the New Year boundary, even for yesterday.
  if (sameYear && date.month == yesterday.month && date.day == yesterday.day) {
    return '昨天';
  }
  return '${date.month}/${date.day}';
}
