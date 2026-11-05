import 'package:flutter/material.dart';
import '../../../contacts/domain/contact_records.dart';
import '../../domain/dial_contact_suggestion.dart';
import '../controller/dial_contacts_controller.dart';

class DialContactSuggestions extends StatelessWidget {
  const DialContactSuggestions({
    super.key,
    required this.query,
    required this.state,
    required this.onSelect,
    required this.onRetry,
    this.enabled = true,
    this.nativeLayout = false,
  });
  final String query;
  final DialContactsState state;
  final ValueChanged<DialContactSuggestion> onSelect;
  final VoidCallback onRetry;
  final bool enabled, nativeLayout;
  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'^[0-9]+$').hasMatch(query.trim())) {
      return const SizedBox.shrink();
    }
    if (nativeLayout &&
        (state.loading ||
            state.failed ||
            (state.access != ContactAccess.authorized &&
                state.access != ContactAccess.limited))) {
      return const SizedBox.shrink();
    }
    if (state.loading) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('正在读取联系人'));
    }
    if (state.failed) {
      return TextButton(onPressed: onRetry, child: const Text('联系人读取失败，重试'));
    }
    if (state.access == ContactAccess.unsupported) {
      return const Text('当前环境无法读取系统联系人', style: TextStyle(fontSize: 12));
    }
    if (state.access != ContactAccess.authorized &&
        state.access != ContactAccess.limited) {
      return const Text('未获通讯录权限，仅支持手动输入', style: TextStyle(fontSize: 12));
    }
    final items = DialSuggestionPolicy.search(query, state.entries);
    if (items.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: nativeLayout ? double.infinity : 180,
      ),
      child: ListView.builder(
        key: const ValueKey('dial-suggestions'),
        primary: false,
        physics: nativeLayout ? const NeverScrollableScrollPhysics() : null,
        shrinkWrap: true,
        padding: EdgeInsets.only(top: nativeLayout ? 0 : 12, bottom: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index], display = item.display;
          final start = display.start, end = display.end;
          return InkWell(
            key: ValueKey('dial-suggestion:$index'),
            onTap: enabled ? () => onSelect(item) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE9E6FF),
                    child: Text(
                      item.name.characters.first,
                      style: const TextStyle(
                        color: Color(0xFF6C55ED),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111318),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(
                            children: start == null || end == null
                                ? [TextSpan(text: display.text)]
                                : [
                                    TextSpan(
                                      text: display.text.substring(0, start),
                                    ),
                                    TextSpan(
                                      text: display.text.substring(start, end),
                                      style: const TextStyle(
                                        color: Color(0xFF1687F8),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: display.text.substring(end)),
                                  ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
