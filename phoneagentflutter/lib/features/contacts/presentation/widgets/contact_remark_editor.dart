import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/contact_providers.dart';
import 'contact_remark_editor_action.dart';

class ContactRemarkEditor extends ConsumerStatefulWidget {
  const ContactRemarkEditor({super.key});

  @override
  ConsumerState<ContactRemarkEditor> createState() =>
      _ContactRemarkEditorState();
}

class _ContactRemarkEditorState extends ConsumerState<ContactRemarkEditor> {
  bool get _editable =>
      mounted &&
      ModalRoute.of(context)?.isCurrent == true &&
      ref.read(contactsControllerProvider).editing &&
      !ref.read(contactsControllerProvider).saving;

  void _cancel() {
    if (_editable) ref.read(contactsControllerProvider.notifier).cancelEdit();
  }

  void _save() {
    if (_editable) ref.read(contactsControllerProvider.notifier).saveRemark();
  }

  void _change(String value) {
    if (_editable) {
      ref.read(contactsControllerProvider.notifier).editRemark(value);
    }
  }

  static final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: Color(0xFFB3B3B3), width: 1.2),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    ref.listen(contactsControllerProvider, (before, after) {
      if (before?.editing == true &&
          !after.editing &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        final accepted =
            before?.saving == true &&
            !after.saving &&
            after.saveError.isEmpty &&
            after.selected?.key == before?.selected?.key;
        Navigator.of(context).pop(accepted);
      }
    });
    return PopScope(
      canPop: !state.saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '编辑备注',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '备注将用于 AI 联系此人时参考',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: '联系人备注',
                child: TextFormField(
                  key: const ValueKey('contact-remark-input'),
                  initialValue: state.draft,
                  enabled: !state.saving,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 19 / 16,
                    letterSpacing: 0,
                    color: Color(0xFF111111),
                  ),
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  onChanged: _change,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    hintText: '例如：称呼、关系、沟通偏好等',
                    hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                    counterText: '',
                    border: _inputBorder,
                    enabledBorder: _inputBorder,
                    disabledBorder: _inputBorder,
                    focusedBorder: _inputBorder,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      state.saveError,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${state.draft.characters.length}/2000',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  ContactRemarkEditorAction(
                    label: '取消',
                    enabled: !state.saving,
                    onPressed: _cancel,
                  ),
                  ContactRemarkEditorAction(
                    label: state.saving ? '保存中…' : '保存',
                    filled: true,
                    enabled: !state.saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
