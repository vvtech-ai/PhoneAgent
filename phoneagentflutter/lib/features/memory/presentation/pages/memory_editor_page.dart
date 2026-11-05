import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/memory_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../domain/account_memory.dart';
import '../../domain/memory_skill_selection.dart';
import '../../domain/memory_mutation_validation.dart';
import '../widgets/memory_confirmation.dart';
import '../widgets/memory_frame.dart';
import '../widgets/memory_skill_tags.dart';
import '../widgets/memory_skill_sheet.dart';

class MemoryEditorPage extends ConsumerStatefulWidget {
  const MemoryEditorPage({super.key, this.entry});
  final MemoryEntry? entry;
  @override
  ConsumerState<MemoryEditorPage> createState() => _MemoryEditorPageState();
}

class _MemoryEditorPageState extends ConsumerState<MemoryEditorPage> {
  late final TextEditingController _text;
  late MemoryScope _scope;
  late Set<String> _skills;
  int? _epoch;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.entry?.content ?? '');
    _scope = widget.entry?.scope ?? MemoryScope.selected;
    _skills = {...?widget.entry?.skillIds};
    _epoch = ref.read(loginEpochProvider);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change) {
    ref.read(memoryControllerProvider.notifier).clearFailure();
    setState(change);
  }

  Future<void> _selectSkills(List<MemorySkill> skills) async {
    FocusScope.of(context).unfocus();
    final available = skills
        .where((skill) => skill.enabled)
        .map((skill) => skill.id)
        .toSet();
    final selection = await showModalBottomSheet<MemorySkillSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemorySkillSheet(
        initial: MemorySkillSelection(
          _scope == MemoryScope.all,
          _skills.intersection(available),
        ),
        skills: skills,
      ),
    );
    if (!mounted ||
        selection == null ||
        ref.read(loginEpochProvider) != _epoch) {
      return;
    }
    _edit(() {
      _scope = selection.all ? MemoryScope.all : MemoryScope.selected;
      _skills = selection.applyTo(_skills, available);
    });
  }

  Future<void> _apply(MemoryAction action, {bool retry = false}) async {
    final controller = ref.read(memoryControllerProvider.notifier);
    if (retry && controller.failedAction == null) {
      await controller.load();
      return;
    }
    final saved = retry
        ? await controller.retry()
        : await controller.apply(action);
    if (!mounted || ref.read(loginEpochProvider) != _epoch) return;
    if (saved) {
      showNativeNotice(context, ref.read(memoryControllerProvider).notice);
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (!await confirmMemoryDeletion(context, all: false)) return;
    if (!mounted || ref.read(loginEpochProvider) != _epoch) return;
    await _apply(MemoryAction('DELETE', id: widget.entry!.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryControllerProvider);
    final controller = ref.read(memoryControllerProvider.notifier);
    ref.listen(loginEpochProvider, (_, epoch) {
      if (epoch != _epoch) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    final original = widget.entry;
    final missingEntry =
        original != null &&
        state.snapshot != null &&
        !state.snapshot!.entries.any((entry) => entry.id == original.id);
    final content = _text.text.trim();
    final dirty =
        content != (original?.content ?? '') ||
        _scope != (original?.scope ?? MemoryScope.selected) ||
        _skills.length != (original?.skillIds.length ?? 0) ||
        !_skills.containsAll(original?.skillIds ?? []);
    final action = MemoryAction(
      original == null ? 'ADD' : 'UPDATE',
      id: original?.id,
      content: content,
      scope: _scope,
      skillIds: _skills.toList(),
    );
    final invalid = missingEntry
        ? '该条记忆已不存在，请返回后重新选择'
        : state.snapshot != null && dirty && content.isNotEmpty
        ? MemoryMutationValidation.error(state.snapshot!, action)
        : null;
    final valid =
        state.snapshot != null &&
        !state.busy &&
        content.isNotEmpty &&
        dirty &&
        !state.refreshable &&
        invalid == null &&
        (_scope == MemoryScope.all || _skills.isNotEmpty);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) Future.microtask(controller.clearFailure);
      },
      child: MemoryFrame(
        title: original == null ? '添加记忆' : '编辑记忆',
        busy: state.busy,
        error: state.error.isNotEmpty ? state.error : invalid ?? '',
        retryLabel: state.refreshable ? '刷新' : '重试',
        onRetry: (state.retryable || state.refreshable) && invalid == null
            ? () => _apply(action, retry: true)
            : null,
        action: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 38,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MemoryColors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE7EAF0),
                disabledForegroundColor: const Color(0xFFABB2BF),
                minimumSize: const Size(64, 38),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical:
                      ((38 - MediaQuery.textScalerOf(context).scale(14)) / 2)
                          .clamp(0.0, 8.0),
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: valid ? () => _apply(action) : null,
              child: Text(
                state.busy ? '保存中' : '保存',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            MemorySkillTags(
              scope: _scope,
              ids: _skills,
              skills: state.snapshot?.skills ?? [],
              enabled: !state.busy,
              onRemove: (id) => _edit(() {
                if (id == null) {
                  _scope = MemoryScope.selected;
                } else {
                  _skills.remove(id);
                }
              }),
              onOpen: () => _selectSkills(state.snapshot?.skills ?? []),
            ),
            const SizedBox(height: 24),
            MemoryCard(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 280),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _text,
                    enabled: !state.busy,
                    minLines: 8,
                    maxLines: null,
                    cursorColor: MemoryColors.blue,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 28 / 17,
                      color: MemoryColors.text,
                    ),
                    onChanged: (_) => _edit(() {}),
                    decoration: const InputDecoration(
                      hintText: '输入需要 AI 记住的内容',
                      hintStyle: TextStyle(
                        fontSize: 17,
                        height: 28 / 17,
                        color: MemoryColors.secondary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
            if (original != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Center(
                  child: TextButton(
                    onPressed: state.busy || missingEntry ? null : _delete,
                    child: const Text(
                      '删除这条记忆',
                      style: TextStyle(fontSize: 16, color: MemoryColors.red),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
