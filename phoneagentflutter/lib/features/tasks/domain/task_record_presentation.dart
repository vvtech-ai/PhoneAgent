import '../../../core/domain/record_time.dart';
import 'task_records.dart';

/// Ports the reachable v66 TaskDisplayTextPolicy title rules only.
/// SDK resource identity, ordering and task status remain unchanged.
class TaskRecordPresentation {
  static String title(TaskRecord row) {
    if (row.kind == TaskRecordKind.translation) return row.title;
    final scene = _scene(row);
    final parts = row.title
        .trim()
        .split('·')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final candidate = parts.length > 1 && _sceneLabel(parts.first, scene)
        ? parts.skip(1).join(' · ')
        : parts.join(' · ');
    var target = _sanitize(scene, candidate);
    if (target.isEmpty) {
      final text = '${row.title} · ${row.summary}';
      target = _sanitize(
        scene,
        (scene == '会议通知'
                ? RegExp(r'\d+\s*位参会人').firstMatch(text)?.group(0)
                : null) ??
            RegExp(
              r'([\u4e00-\u9fa5A-Za-z0-9·-]{2,20}(?:店|餐厅|酒店|牛排|火锅|会议|周会))',
            ).firstMatch(text)?.group(0) ??
            '',
      );
    }
    if (target.isEmpty) {
      target = switch (scene) {
        '订餐厅' => '餐厅',
        '订酒店' => '酒店',
        '订机票' => '航班',
        '会议通知' => '参会人',
        _ => '目标对象',
      };
    }
    final prefix = row.sceneTitle.isNotEmpty ? row.sceneTitle : scene;
    return '$prefix · $target';
  }

  static String _scene(TaskRecord row) {
    final scene = row.scene.toUpperCase(),
        text = '${row.title} · ${row.summary}';
    if (scene == 'FOOD_ORDERING' || scene == 'RESTAURANT_BOOKING') return '订餐厅';
    if (scene == 'HOTEL_BOOKING') return '订酒店';
    if (scene == 'FLIGHT_BOOKING') return '订机票';
    if (scene.contains('MEETING')) return '会议通知';
    if (scene == 'AI_CALL') return 'AI 通话';
    const keywords = {
      '会议通知': ['会议', '参会', '回执', '邀请', '通知'],
      '订酒店': ['酒店', '入住', '离店', '房型', '无烟房'],
      '订机票': ['机票', '航班', '出发', '目的地', '舱位'],
      '订餐厅': ['餐厅', '订餐', '订位', '包房', '包间', '低消', '海底捞', '新荣记', '西堤'],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return 'AI 通话';
  }

  static bool _sceneLabel(String value, String scene) {
    final compact = value.replaceAll(' ', '');
    return compact == scene.replaceAll(' ', '') ||
        compact.contains('任务') ||
        const {
          '订餐厅',
          '订餐',
          '订酒店',
          '酒店预订',
          '订机票',
          '会议通知',
          '会议邀请',
          'AI通话',
        }.contains(compact);
  }

  static String _sanitize(String scene, String raw) {
    String trim(String value) =>
        value.trim().replaceAll(RegExp(r'^[ ：:\-—·]+|[ ：:\-—·]+$'), '');
    var value = trim(raw)
        .replaceFirst(RegExp(r'^(请帮我|帮我|我要|我想|需要|帮忙)\s*'), '')
        .replaceFirst(
          RegExp(
            r'^(订餐任务|订餐厅|订餐|订酒店任务|订酒店|酒店任务|订机票任务|订机票|会议通知|会议邀请|AI\s*通话任务|AI\s*任务)\s*',
          ),
          '',
        );
    value = trim(value);
    if (value.startsWith(scene)) value = trim(value.substring(scene.length));
    value = value.split(RegExp(r'[。，；;\n]')).first.trim();
    if (value.isEmpty ||
        const {'餐厅', '酒店', '任务', '目标对象', '进行中的对话'}.contains(value) ||
        ['正在同步', '同步失败', '点击继续'].any(value.contains) ||
        RegExp(
          r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?$',
        ).hasMatch(value)) {
      return '';
    }
    return value.length > 22 ? value.substring(0, 22) : value;
  }

  static String time(String raw, {DateTime? now}) =>
      recordTimeLabel(raw, now: now, invalidFallback: raw);
}
