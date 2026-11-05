import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_creation_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_creation_sheet.dart';
import '../../test/support/synthetic_account_api.dart';

/// Offline HTTP-adapter fixture using the production parser and picker.
/// No real account, network, identity SDK, storage, recording or billing.
void main() => runApp(const MaterialApp(home: CatalogReference()));

class CatalogReference extends StatefulWidget {
  const CatalogReference({super.key});
  @override
  State<CatalogReference> createState() => _CatalogReferenceState();
}

class _CatalogReferenceState extends State<CatalogReference> {
  final http = SyntheticAccountApi();
  bool failed = true;
  bool summary = false;
  bool opening = false;
  Future<void> open() async {
    if (opening) return;
    opening = true;
    http.status = failed ? 503 : 200;
    http.data = {
      'models': [
        for (final id in ['QWEN_OMNI_PLUS', 'DOUBAO_SEEDUPLEX_3_0'])
          {
            'modelId': id,
            'available': summary ? 'true' : true,
            'current': summary ? <String, Object?>{} : null,
            'candidate': summary ? {'status': 'PROCESSING'} : null,
          },
      ],
    };
    try {
      await showCloneCreationSheet(
        context,
        ApiCloneCreationPort(
          http.api,
          points: () =>
              Future<int>.error(StateError('Fixture is catalog only')),
          recording: () =>
              Future<bool>.error(StateError('Fixture is catalog only')),
        ),
      );
    } finally {
      opening = false;
    }
  }

  @override
  void dispose() {
    http.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的身份')),
    body: SafeArea(
      child: Column(
        children: [
          const Text('MOCK · 正式目录解析与弹窗；无真实业务'),
          SwitchListTile(
            title: const Text('模拟服务失败'),
            value: failed,
            onChanged: (value) => setState(() => failed = value),
          ),
          SwitchListTile(
            title: const Text('原生候选摘要与字符串布尔值'),
            value: summary,
            onChanged: (value) => setState(() => summary = value),
          ),
          FilledButton(onPressed: open, child: const Text('声音克隆')),
        ],
      ),
    ),
  );
}
