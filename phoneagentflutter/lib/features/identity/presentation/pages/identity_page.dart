import 'package:flutter/material.dart';
import '../../../../core/design/native_detail_header.dart';
import '../../domain/identity_profile.dart';
import '../controller/identity_controller.dart';
import '../widgets/identity_editor.dart';
import '../widgets/identity_widgets.dart';
import '../widgets/identity_status_content.dart';

class IdentityActions {
  const IdentityActions({
    required this.back,
    required this.retry,
    required this.edit,
    required this.cancel,
    required this.save,
    required this.delete,
    required this.models,
    required this.name,
    required this.phone,
    required this.gender,
    this.retryCleanup,
  });
  final VoidCallback back, retry, edit, cancel, save, delete, models;
  final ValueChanged<String> name, phone, gender;
  final VoidCallback? retryCleanup;
}

class IdentityPage extends StatelessWidget {
  const IdentityPage({required this.state, required this.actions, super.key});
  final IdentityState state;
  final IdentityActions actions;
  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: IdentityStyle.body,
    child: Column(
      children: [
        NativeDetailHeader(
          title: '我的身份',
          onBack: state.mutating
              ? null
              : state.editing
              ? actions.cancel
              : actions.back,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              IdentityStatusContent(
                state: state,
                onRetry: actions.retry,
                onRetryCleanup: actions.retryCleanup,
              ),
              if (state.profile != null && !state.initialLoadStatus)
                if (state.editing)
                  IdentityEditor(
                    draft: state.draft,
                    busy: state.busy,
                    verified: state.profile!.status == IdentityStatus.verified,
                    onName: actions.name,
                    onPhone: actions.phone,
                    onGender: actions.gender,
                    onSave: actions.save,
                  )
                else if (state.profile!.status == IdentityStatus.empty)
                  _empty()
                else
                  _profile(state.profile!),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _empty() => Column(
    children: [
      const SizedBox(height: 72),
      const Text(
        '暂无身份信息',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      const Text(
        '用于AI在通话中更好的沟通。',
        style: TextStyle(fontSize: 14, color: IdentityStyle.muted),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: IdentityAction(
          label: '填写身份信息',
          onTap: state.busy || state.cleanupPending ? null : actions.edit,
        ),
      ),
    ],
  );
  Widget _profile(IdentityProfile profile) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      IdentityCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('身份信息', style: IdentityStyle.heading),
                      if (profile.status == IdentityStatus.verified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EE),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            '已认证',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E9D50),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IdentityIconButton(
                  label: '编辑身份',
                  asset: 2,
                  onTap: state.busy ? null : actions.edit,
                ),
                IdentityIconButton(
                  label: '删除身份',
                  asset: 1,
                  onTap: state.busy ? null : actions.delete,
                ),
              ],
            ),
            _row('姓名', profile.name),
            _row(
              '手机号码',
              profile.contactPhone.trim().isEmpty
                  ? '未填写'
                  : profile.contactPhone,
            ),
            _row(
              '性别',
              profile.gender.isEmpty || profile.gender == '不透露'
                  ? '不透露'
                  : profile.gender,
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 14, left: 4),
        child: Text(
          '用于AI在通话中更好的沟通。',
          style: TextStyle(fontSize: 13, color: IdentityStyle.muted),
        ),
      ),
      const SizedBox(height: 16),
      IdentityAction(label: '声音克隆', onTap: state.busy ? null : actions.models),
      const SizedBox(height: 8),
      const Text(
        '声音克隆用于使用我的声音进行 AI 通话',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: IdentityStyle.muted),
      ),
    ],
  );
  Widget _row(String label, String value) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: IdentityStyle.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ),
      ],
    ),
  );
}
