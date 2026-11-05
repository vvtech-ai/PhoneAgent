import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import 'outbound_preview_page.dart';
import 'developer_network_preview_page.dart';
import 'agent_location_preview_page.dart';
import 'agent_context_preview_page.dart';
import 'app_call_records_preview_page.dart';
import '../../../identity/presentation/pages/identity_cleanup_preview_page.dart';
import '../../data/preview_outbound_number_repository.dart';
import '../../../calls/presentation/pages/call_preview_route.dart';
import '../../../calls/presentation/pages/call_flow_preview_page.dart';
import '../../../initialization/presentation/pages/initialization_preview_route.dart';
import '../../../conversation/presentation/pages/receipt_preview_page.dart';
import '../../../conversation/presentation/pages/batch_flow_preview_page.dart';
import '../../../conversation/presentation/pages/permission_preview_page.dart';
import '../../../conversation/presentation/pages/voice_input_preview_page.dart';
import '../../../translation_history/presentation/pages/recording_preview_page.dart';
import '../../../app_update/presentation/pages/startup_update_preview_page.dart';
import '../../../translation/presentation/pages/translation_location_preview_page.dart';
import '../../../translation/presentation/pages/translation_access_preview_page.dart';
import '../../../translation/presentation/pages/translation_session_preview_page.dart';

/// Synthetic UI only; none of these values are business or platform settings.
class DeveloperPreviewPage extends StatefulWidget {
  const DeveloperPreviewPage({super.key, this.showWebRtcControls = true});
  final bool showWebRtcControls;
  @override
  State<DeveloperPreviewPage> createState() => _DeveloperPreviewPageState();
}

class _DeveloperPreviewPageState extends State<DeveloperPreviewPage> {
  String _list = '未操作',
      _number = '',
      _network = '正常',
      _region = 'Default',
      _provider = 'Gemini',
      _message = '';
  bool _webrtc = false;
  Future<void> _outbound() async {
    final repository = PreviewOutboundNumberRepository(number: _number);
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => OutboundPreviewPage(repository: repository),
      ),
    );
    if (mounted) setState(() => _number = repository.value.number);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('开发者功能演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'MOCK · 不影响真实列表、外呼号码、网络或系统权限',
            style: ShellTokens.subtitle,
          ),
          ListTile(
            title: const Text('本机记录与列表演练'),
            subtitle: const Text('追加、最近记录、清空/充实与失败重试 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const AppCallRecordsPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('身份删除后本地处理演练'),
            subtitle: const Text('删除成功、本地失败与安全重试 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const IdentityCleanupPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('翻译共享会话演练'),
            subtitle: const Text('真实协议合成事件、字幕、控制与终态 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const TranslationSessionPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('对话时间与权限上下文演练'),
            subtitle: const Text('每轮快照、跨日、时区与失败降级 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const AgentContextPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('对话位置上下文演练'),
            subtitle: const Text('坐标/地址、缓存与失败保留 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const AgentLocationPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('网络三态与在线入口演练'),
            subtitle: const Text('共享正式门禁、重试、返回与系统拨号例外 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const DeveloperNetworkPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('当前位置与区号演练'),
            subtitle: const Text('定位、权限、可信缓存与手动选择 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const TranslationLocationPreviewPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('统一对话权限演练'),
            subtitle: const Text('允许、拒绝、需设置与继续对话 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const PermissionPreviewPage()),
            ),
          ),
          ListTile(
            title: const Text('统一对话输入演练'),
            subtitle: const Text('按住、上滑取消、收尾、切文字 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const VoiceInputPreviewPage()),
            ),
          ),
          ListTile(
            title: const Text('对话到通话全流程演练'),
            subtitle: const Text('自动确认、积分、单路/多路、回执 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const CallFlowScenariosPage()),
            ),
          ),
          ListTile(
            title: const Text('单路通话页面演练'),
            subtitle: const Text('监听、挂断、音源与转写 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const CallPreviewScenariosPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('统一对话回执演练'),
            subtitle: const Text('单路结果、批量进度和逐项通话记录 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptPreviewPage()),
            ),
          ),
          ListTile(
            title: const Text('批量进度与退出演练'),
            subtitle: const Text('逐项更新、退出保留接收、历史恢复 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const BatchFlowPreviewPage()),
            ),
          ),
          ListTile(
            title: const Text('首次初始化演练'),
            subtitle: const Text('身份、模型、跳过与失败重试 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const InitializationScenariosPage(),
              ),
            ),
          ),
          ListTile(
            title: const Text('翻译历史录音演练'),
            subtitle: const Text('加载、播放暂停、保存与失败重试 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const RecordingScenariosPage()),
            ),
          ),
          ListTile(
            title: const Text('启动更新与强制提示演练'),
            subtitle: const Text('每日检查、强制、恢复与安装取消 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const StartupUpdateScenariosPage(),
              ),
            ),
          ),
          _section('列表数据', [
            Text('真实数据状态（演练）：$_list'),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _list = '已模拟重新拉取'),
                  child: const Text('重新拉取'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _list = '已模拟清空，真实列表未改变'),
                  child: const Text('清空列表'),
                ),
              ],
            ),
          ]),
          _section('外呼调试', [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('固定外呼号码'),
              subtitle: Text(_number.isEmpty ? '未配置（MOCK）' : 'MOCK · $_number'),
              trailing: const Text('编辑'),
              onTap: _outbound,
            ),
          ]),
          _section('设备位置', [
            const Text('当前定位：未获取到位置信息'),
            const Text('演练不申请定位权限', style: ShellTokens.subtitle),
          ]),
          if (widget.showWebRtcControls)
            _section('实时翻译调试', [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('国内强制 WebRTC'),
                subtitle: const Text('MOCK · 仅演练开关，不启用国内 SIP；真实链路尚未接入'),
                value: _webrtc,
                onChanged: (v) => setState(() => _webrtc = v),
              ),
              const Text('国外服务器'),
              _choices(
                ['US', 'JP'],
                _region,
                (v) => setState(() => _region = v),
              ),
              const Text('国外通话模型'),
              _choices(
                ['OpenAI', 'Gemini'],
                _provider,
                (v) => setState(() => _provider = v),
              ),
              const Text('这些选择不写入下一通真实翻译通话', style: ShellTokens.subtitle),
            ]),
          _section('V8.8 模拟能力', [
            const Text('网络状态模拟'),
            _choices(
              ['正常', '弱网', '断网'],
              _network,
              (v) => setState(() => _network = v),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _message = 'MOCK · 模拟权限记录已重置；系统权限未改变'),
              child: const Text('重置所有权限'),
            ),
            const Text('清除模拟权限记录，不撤销系统权限', style: ShellTokens.subtitle),
            if (_message.isNotEmpty) Text(_message),
          ]),
          ListTile(
            title: const Text('翻译地区准入与倍率演练'),
            subtitle: const Text('地区、强制开关、节点、账号倍率 · MOCK'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const TranslationAccessPreviewPage(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: ShellTokens.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
  Widget _choices(
    List<String> items,
    String selected,
    ValueChanged<String> onSelect,
  ) => Wrap(
    spacing: 10,
    children: [
      for (final item in items)
        ChoiceChip(
          label: Text(item),
          selected: item == selected,
          onSelected: (_) => onSelect(item),
        ),
    ],
  );
}
