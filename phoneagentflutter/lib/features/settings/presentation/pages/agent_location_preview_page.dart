import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/agent_location_providers.dart';
import '../../../../app/business_providers.dart';
import '../../../conversation/domain/context/agent_location.dart';
import '../../../conversation/presentation/controller/agent_location_controller.dart';
import '../widgets/developer_location_summary.dart';

class AgentLocationPreviewPage extends StatefulWidget {
  const AgentLocationPreviewPage({super.key});
  @override
  State<AgentLocationPreviewPage> createState() =>
      _AgentLocationPreviewPageState();
}

class _AgentLocationPreviewPageState extends State<AgentLocationPreviewPage> {
  final source = _PreviewLocation();
  Duration elapsed = Duration.zero;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      loginEpochProvider.overrideWithValue(0),
      agentLocationSourceProvider.overrideWithValue(source),
      agentLocationProvider.overrideWith(
        (ref) => AgentLocationController(source, elapsed: () => elapsed),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) => Scaffold(
        appBar: AppBar(title: const Text('对话位置上下文演练')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('MOCK · 合成位置；不采集设备位置、不发起对话或接口请求'),
              const DeveloperLocationSummary(),
              for (final mode in ['未授权', '坐标', '地址', '失败'])
                RadioListTile<String>(
                  title: Text(mode),
                  value: mode,
                  groupValue: source.mode,
                  onChanged: (value) => setState(() => source.mode = value!),
                ),
              FilledButton(
                onPressed: () async {
                  final value = await ref
                      .read(agentLocationProvider.notifier)
                      .context();
                  if (mounted) {
                    setState(() => source.submitted = value.keys.join(', '));
                  }
                },
                child: const Text('模拟一轮对话前读取'),
              ),
              OutlinedButton(
                onPressed: () =>
                    setState(() => elapsed += const Duration(minutes: 3)),
                child: const Text('推进3分钟（缓存到期）'),
              ),
              Text('取样次数：${source.reads}；本轮位置字段：${source.submitted}'),
              const Text('2分钟内复用；过期读取失败仍保留本账号上次成功位置。位置不会写入磁盘或影响所选拨号国家。'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PreviewLocation implements AgentLocationSource {
  String mode = '未授权', submitted = '无';
  int reads = 0;
  @override
  Future<AgentLocation?> read() async {
    reads++;
    return switch (mode) {
      '坐标' => AgentLocation(22.5, 114.0),
      '地址' => AgentLocation(22.5, 114.0, address: '合成地址 · 演练街道'),
      '失败' => throw StateError('Synthetic failure'),
      _ => null,
    };
  }

  @override
  Future<void> cancel() async {}
}
