import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'workbench_catalog.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Workbench is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(const MigrationWorkbench());
}

/// Tool-only entry, never imported by lib/main.dart. No configured API or proxy.
class MigrationWorkbench extends StatefulWidget {
  const MigrationWorkbench({super.key, this.scenes});
  final List<WorkbenchScene>? scenes;
  @override
  State<MigrationWorkbench> createState() => _MigrationWorkbenchState();
}

class _MigrationWorkbenchState extends State<MigrationWorkbench> {
  WorkbenchScene? _selected;
  final _search = TextEditingController();
  final _rootNavigator = GlobalKey<NavigatorState>();
  int _generation = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(WorkbenchScene? scene) => setState(() {
    // Root dialogs belong to the selected scene too, not the catalog.
    _rootNavigator.currentState?.popUntil((route) => route.isFirst);
    _selected = scene;
    _generation++;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PhoneAgent 迁移验收目录 · MOCK',
    debugShowCheckedModeBanner: false,
    navigatorKey: _rootNavigator,
    builder: (_, child) => MobilePreview(
      child: SafeArea(
        child: Column(
          // Paint outside and after every Navigator, including root dialogs.
          verticalDirection: VerticalDirection.up,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(size: constraints.biggest),
                  child: child!,
                ),
              ),
            ),
            Material(child: _toolbar()),
          ],
        ),
      ),
    ),
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6C55ED),
    ),
    home: PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selected != null) _select(null);
      },
      child: Scaffold(body: _selected == null ? _catalog() : _scene()),
    ),
  );

  Widget _toolbar() => ColoredBox(
    color: const Color(0xFFFFF3CD),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_selected != null)
            TextButton(
              key: const ValueKey('workbench-home'),
              onPressed: () => _select(null),
              child: const Text('返回目录'),
            ),
          Expanded(
            child: Text(
              _selected == null
                  ? 'MOCK · 迁移验收目录'
                  : 'MOCK · ${_selected!.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _scene() => LayoutBuilder(
    builder: (context, constraints) {
      final scene = _selected!;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(size: constraints.biggest),
        child: KeyedSubtree(
          key: ValueKey('scene-$_generation'),
          child: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: scene.build),
          ),
        ),
      );
    },
  );

  Widget _catalog() {
    final all = widget.scenes ?? workbenchScenes;
    final matching = all.where(
      (s) => '${s.group} ${s.title} ${s.boundary}'.toLowerCase().contains(
        _search.text.toLowerCase(),
      ),
    );
    return ListView(
      key: const ValueKey('workbench-catalog'),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '共享 Flutter 页面，集中查看',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${all.length} 个场景入口 · 不发短信、不外呼、不安装\n'
          '只替换外部端口；视觉统一后校准。目录不是完整迁移通过证明。',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('workbench-search'),
          controller: _search,
          decoration: const InputDecoration(
            labelText: '搜索模块或场景',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (matching.isEmpty) const Text('没有匹配场景，请修改搜索内容'),
        for (final group in matching.map((s) => s.group).toSet()) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              group,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final scene in matching.where((s) => s.group == group))
            Card(
              child: ListTile(
                key: ValueKey('scene-${scene.id}'),
                title: Text(scene.title),
                subtitle: Text(scene.boundary),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _select(scene);
                },
              ),
            ),
        ],
      ],
    );
  }
}
