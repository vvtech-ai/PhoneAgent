import 'dart:convert';

class SseFrame {
  const SseFrame(this.event, this.data, {this.id});
  final String event, data;
  final String? id;
}

/// UTF-8 decoder owns split codepoints; framing owns CR/LF and multiline data.
/// No reconnect or POST replay is performed here.
class SseFrameDecoder {
  const SseFrameDecoder({this.maximumFrameCharacters = 2 * 1024 * 1024});
  final int maximumFrameCharacters;

  Stream<SseFrame> decode(Stream<List<int>> bytes) async* {
    var buffer = '', event = 'message';
    String? id;
    final data = <String>[];
    var length = 0, skipLf = false;
    await for (final chunk in utf8.decoder.bind(bytes)) {
      buffer += chunk;
      while (buffer.isNotEmpty) {
        if (skipLf) {
          if (buffer.startsWith('\n')) buffer = buffer.substring(1);
          skipLf = false;
        }
        final delimiter = buffer.indexOf(RegExp(r'[\r\n]'));
        if (delimiter < 0) break;
        final line = buffer.substring(0, delimiter);
        if (line.length > maximumFrameCharacters) {
          throw const FormatException('SSE line exceeds size limit');
        }
        skipLf = buffer[delimiter] == '\r';
        buffer = buffer.substring(delimiter + 1);
        if (line.isEmpty) {
          if (data.isNotEmpty) yield SseFrame(event, data.join('\n'), id: id);
          event = 'message';
          data.clear();
          length = 0;
          continue;
        }
        if (line.startsWith(':')) continue;
        final colon = line.indexOf(':');
        final field = colon < 0 ? line : line.substring(0, colon);
        var value = colon < 0 ? '' : line.substring(colon + 1);
        if (value.startsWith(' ')) value = value.substring(1);
        switch (field) {
          case 'event':
            event = value.isEmpty ? 'message' : value;
          case 'id':
            if (!value.contains('\u0000')) id = value;
          case 'data':
            data.add(value);
            length += value.length + 1;
        }
        if (length > maximumFrameCharacters ||
            line.length > maximumFrameCharacters) {
          throw const FormatException('SSE frame exceeds size limit');
        }
      }
      if (buffer.length + length > maximumFrameCharacters) {
        throw const FormatException('SSE frame exceeds size limit');
      }
    }
    // An unterminated frame is discarded, not treated as a successful `done`.
  }
}
