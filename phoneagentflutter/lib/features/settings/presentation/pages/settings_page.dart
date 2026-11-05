import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../../../core/design/native_setting_controls.dart';
import '../widgets/settings_logout_button.dart';
import '../../../invite/domain/invite_entry_presentation.dart';

enum SettingsDestination {
  identity,
  homeCards,
  memory,
  models,
  originalAudio,
  invite,
  trustedCaller,
  about,
  feedback,
  developer,
  logout,
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onOpen,
    required this.developer,
    required this.modelSummary,
    required this.originalSummary,
    this.identitySummary = '',
    this.loginPhone = '未登录',
    this.inviteEntry,
  });
  final ValueChanged<SettingsDestination> onOpen;
  final bool developer;
  final String modelSummary, originalSummary;
  final String identitySummary;
  final String loginPhone;
  final InviteEntryPresentation? inviteEntry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          '设置',
          style: TextStyle(
            fontSize: 28,
            height: 40 / 28,
            fontWeight: FontWeight.w800,
            color: ShellTokens.ink,
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
          children: [
            _entry(SettingsDestination.memory, '记忆', '管理在任务中使用的背景与偏好'),
            _entry(
              SettingsDestination.homeCards,
              'Skill 卡片',
              '调整首页Skill 卡片的顺序与显示',
            ),
            _entry(
              SettingsDestination.models,
              '语音模型与音色',
              '通话AI语音、任务AI语音',
              modelSummary,
            ),
            _entry(
              SettingsDestination.originalAudio,
              '实时翻译原音',
              '设置实时翻译通话的原声播放与混合比例',
              originalSummary,
            ),
            if (inviteEntry?.visible == true)
              _entry(SettingsDestination.invite, '邀请好友', inviteEntry!.subtitle),
            _entry(
              SettingsDestination.trustedCaller,
              '可信来电MCP服务',
              '验证来电者的身份签名和证书',
            ),
            _entry(SettingsDestination.feedback, '问题反馈', '告诉我们遇到的问题或建议'),
            _entry(SettingsDestination.about, '关于PhoneAgent', '产品信息与相关协议'),
            if (developer)
              _entry(
                SettingsDestination.developer,
                '开发者功能',
                '调试日志、网络状态、SIP 诊断',
              ),
            SettingsLogoutButton(
              key: const Key('settings-logout'),
              loginPhone: loginPhone,
              onTap: () => onOpen(SettingsDestination.logout),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _entry(
    SettingsDestination id,
    String title,
    String subtitle, [
    String value = '',
  ]) => NativeSettingCard(
    key: Key('settings-${id.name}'),
    isAction: true,
    homeLayout: true,
    title: title,
    subtitle: subtitle,
    value: value.isEmpty ? '›' : '$value ›',
    onTap: () => onOpen(id),
  );
}
