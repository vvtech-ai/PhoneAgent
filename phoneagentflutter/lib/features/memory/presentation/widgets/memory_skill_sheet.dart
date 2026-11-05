import 'package:flutter/material.dart';
import '../../domain/account_memory.dart';
import '../../domain/memory_skill_selection.dart';
import 'memory_frame.dart';

class MemorySkillSheet extends StatefulWidget {
  const MemorySkillSheet({
    super.key,
    required this.initial,
    required this.skills,
  });
  final MemorySkillSelection initial;
  final List<MemorySkill> skills;
  @override
  State<MemorySkillSheet> createState() => _MemorySkillSheetState();
}

class _MemorySkillSheetState extends State<MemorySkillSheet> {
  late MemorySkillSelection selection = widget.initial;
  @override
  Widget build(BuildContext context) {
    final skills = widget.skills.where((skill) => skill.enabled).toList();
    final available = skills.map((skill) => skill.id).toSet();
    final bool? all = selection.all
        ? true
        : selection.ids.any(available.contains)
        ? null
        : false;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          color: MemoryColors.secondary,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '选择适用任务',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: MemoryColors.text,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, selection),
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          color: MemoryColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * .65).clamp(
                    0,
                    420,
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Material(
                      color: MemoryColors.lightBlue,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: const Key('memory-all-skills'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () =>
                            setState(() => selection = selection.toggleAll()),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 62),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '全部任务',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: MemoryColors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Checkbox(
                                  tristate: true,
                                  value: all,
                                  activeColor: MemoryColors.blue,
                                  onChanged: (_) => setState(
                                    () => selection = selection.toggleAll(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, color: MemoryColors.divider),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 4),
                      child: Text(
                        '具体任务',
                        style: TextStyle(
                          fontSize: 13,
                          color: MemoryColors.secondary,
                        ),
                      ),
                    ),
                    for (final skill in skills)
                      InkWell(
                        key: ValueKey('memory-skill-${skill.id}'),
                        onTap: () => setState(
                          () =>
                              selection = selection.toggle(skill.id, available),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 58),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    skill.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: MemoryColors.text,
                                    ),
                                  ),
                                ),
                                Checkbox(
                                  value:
                                      selection.all ||
                                      selection.ids.contains(skill.id),
                                  activeColor: MemoryColors.blue,
                                  onChanged: (_) => setState(
                                    () => selection = selection.toggle(
                                      skill.id,
                                      available,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (skills.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '暂无可用的适用任务',
                          style: TextStyle(
                            fontSize: 14,
                            color: MemoryColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
