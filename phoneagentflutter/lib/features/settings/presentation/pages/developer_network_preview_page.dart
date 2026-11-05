import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/developer_network_providers.dart';
import '../../../../app/online_entry_providers.dart';
import '../../data/preview_network_availability.dart';
import '../../domain/developer_network_mode.dart';
import '../../domain/network_availability.dart';
import '../widgets/developer_network_controls.dart';
import '../widgets/online_entry_guard.dart';

class DeveloperNetworkPreviewPage extends StatefulWidget {
  const DeveloperNetworkPreviewPage({super.key});
  @override
  State<DeveloperNetworkPreviewPage> createState() =>
      _DeveloperNetworkPreviewPageState();
}

class _DeveloperNetworkPreviewPageState
    extends State<DeveloperNetworkPreviewPage> {
  final _source = PreviewNetworkAvailability();
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      networkAvailabilitySourceProvider.overrideWithValue(_source),
      developerNetworkModeProvider.overrideWith(
        (_) => DeveloperNetworkMode.normal,
      ),
    ],
    child: _NetworkPreview(source: _source),
  );
}

class _NetworkPreview extends StatefulWidget {
  const _NetworkPreview({required this.source});
  final PreviewNetworkAvailability source;
  @override
  State<_NetworkPreview> createState() => _NetworkPreviewState();
}

class _NetworkPreviewState extends State<_NetworkPreview> {
  int _onlineEntries = 0, _systemEntries = 0;
  String _lastEntry = '未操作';

  Future<void> _enter(String name) async {
    if (!await allowOnlineEntry(context) || !mounted) return;
    setState(() {
      _onlineEntries++;
      _lastEntry = name;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('网络入口演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 共用正式控件和门禁；只统计动作，不创建会话、请求或电话。'),
          const SizedBox(height: 16),
          const DeveloperNetworkControls(),
          const SizedBox(height: 16),
          const Text('合成系统状态（不调用真实设备）'),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                NetworkAvailability.available: '系统在线',
                NetworkAvailability.unavailable: '系统离线',
                NetworkAvailability.unknown: '检测未知',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: widget.source.value == entry.key,
                  onSelected: (_) =>
                      setState(() => widget.source.value = entry.key),
                ),
            ],
          ),
          SwitchListTile(
            title: const Text('模拟检测异常'),
            value: widget.source.fail,
            onChanged: (value) => setState(() => widget.source.fail = value),
          ),
          const SizedBox(height: 16),
          for (final name in ['首页新对话', '任务恢复', '联系人需求', '翻译呼叫'])
            OutlinedButton(onPressed: () => _enter(name), child: Text(name)),
          OutlinedButton(
            onPressed: () => setState(() => _systemEntries++),
            child: const Text('普通系统拨号（MOCK）'),
          ),
          Text('在线入口通过：$_onlineEntries；最近：$_lastEntry'),
          Text('系统拨号入口通过：$_systemEntries（未拨号）'),
          const Text('检测未知/异常不伪报在线：允许业务尝试，再按真实请求结果处理。'),
          const Text('返回后丢弃本页模拟模式，正式开发者设置不变。'),
        ],
      ),
    ),
  );
}
