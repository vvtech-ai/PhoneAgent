import 'dart:convert';
import 'dart:typed_data';
import '../../domain/sip/sip_lease.dart';

/// Minimal protobuf wire subset used by native Doubao AST, no SDK dependency.
class DoubaoProtoWriter {
  final _bytes = BytesBuilder(copy: false);
  void integer(int field, int value) {
    _tag(field, 0);
    _varint(value);
  }

  void text(int field, String value) {
    if (value.isNotEmpty) bytes(field, Uint8List.fromList(utf8.encode(value)));
  }

  void bytes(int field, Uint8List value) {
    _tag(field, 2);
    _varint(value.length);
    _bytes.add(value);
  }

  void _tag(int field, int type) {
    if (field < 1 || field > 0x1fffffff) {
      throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
    }
    _varint((field << 3) | type);
  }

  void _varint(int value) {
    if (value < 0 || value > 0xffffffff) {
      throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
    }
    while (value >= 128) {
      _bytes.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    _bytes.addByte(value);
  }

  Uint8List build() => _bytes.toBytes();
}

class DoubaoProtoField {
  const DoubaoProtoField(this.number, this.value);
  final int number;
  final Object value;
}

abstract final class DoubaoProtoReader {
  static List<DoubaoProtoField> fields(Uint8List bytes) {
    if (bytes.length > 2 * 1024 * 1024) {
      throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
    }
    var cursor = 0;
    int integer() {
      var value = 0;
      for (var shift = 0; shift < 35; shift += 7) {
        if (cursor >= bytes.length) {
          throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
        }
        final byte = bytes[cursor++];
        if (shift == 28 && byte > 15) {
          throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
        }
        value |= (byte & 0x7f) << shift;
        if ((byte & 0x80) == 0) return value;
      }
      throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
    }

    void skip(int size) {
      if (size < 0 || cursor + size > bytes.length) {
        throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
      }
      cursor += size;
    }

    final fields = <DoubaoProtoField>[];
    while (cursor < bytes.length) {
      final tag = integer(), number = tag >> 3;
      if (number == 0 || number > 0x1fffffff || fields.length >= 4096) {
        throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
      }
      switch (tag & 7) {
        case 0:
          fields.add(DoubaoProtoField(number, integer()));
        case 1:
          skip(8);
        case 2:
          final length = integer(), start = cursor;
          skip(length);
          fields.add(
            DoubaoProtoField(
              number,
              Uint8List.fromList(bytes.sublist(start, cursor)),
            ),
          );
        case 5:
          skip(4);
        default:
          throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
      }
    }
    return fields;
  }
}

class DoubaoProtoResponse {
  const DoubaoProtoResponse(this.event, this.status, this.audio, this.text);
  final int event, status;
  final Uint8List audio;
  final String text;
  static DoubaoProtoResponse decode(Uint8List bytes) {
    try {
      return _decode(bytes);
    } catch (_) {
      throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
    }
  }

  static DoubaoProtoResponse _decode(Uint8List bytes) {
    var event = 0, status = 0;
    var audio = Uint8List(0), text = '';
    for (final field in DoubaoProtoReader.fields(bytes)) {
      switch (field.number) {
        case 1:
          for (final meta in DoubaoProtoReader.fields(
            field.value as Uint8List,
          )) {
            if (meta.number == 3) status = meta.value as int;
          }
        case 2:
          event = field.value as int;
        case 3:
          audio = field.value as Uint8List;
        case 4:
          text = utf8.decode(field.value as Uint8List);
      }
    }
    return DoubaoProtoResponse(event, status, audio, text);
  }
}
