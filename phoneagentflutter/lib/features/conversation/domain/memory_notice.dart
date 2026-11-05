/// Display-only prefix returned together with a normal interactive response.
abstract final class MemoryNotice {
  static String prefix(String text) {
    final value = text.trim();
    if (!value.startsWith('记忆功能未开启')) return '';
    final paragraph = value.split('\n\n').first;
    return paragraph.contains('未保存') || paragraph.contains('未执行')
        ? paragraph
        : '';
  }
}
