import 'package:flutter/material.dart';
import '../../../../core/design/native_setting_controls.dart';
import '../controller/developer_list_controller.dart';

class DeveloperListControls extends StatelessWidget {
  const DeveloperListControls({
    super.key,
    required this.state,
    required this.onApply,
  });
  final DeveloperListState state;
  final ValueChanged<DeveloperListMode> onApply;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '真实数据状态',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
      ),
      const SizedBox(height: 6),
      const Text('用于清空当前列表或重新拉取真实数据'),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            for (final mode in DeveloperListMode.values) ...[
              Expanded(
                child: NativeSettingChoice(
                  key: ValueKey('developer-list-${mode.name}'),
                  label: mode == DeveloperListMode.filled ? '重新拉取' : '清空列表',
                  selected: state.mode == mode,
                  onTap: state.busy ? null : () => onApply(mode),
                ),
              ),
              if (mode == DeveloperListMode.filled) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
      if (state.busy) const LinearProgressIndicator(),
      if (state.message.isNotEmpty)
        Text(
          state.message,
          style: TextStyle(
            color: state.failed ? Theme.of(context).colorScheme.error : null,
          ),
        ),
    ],
  );
}
