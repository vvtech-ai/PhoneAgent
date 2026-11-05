import 'sip_lease.dart';

enum SipAudioCodec { pcmu, pcma }

class SipAudioEndpoint {
  const SipAudioEndpoint(
    this.address,
    this.port,
    this.payloadType,
    this.codec,
    this.telephoneEventPayload,
  );
  final String address;
  final int port, payloadType;
  final SipAudioCodec codec;
  final int? telephoneEventPayload;
}

abstract final class SipSdp {
  static SipAudioEndpoint parse(String sdp) {
    final lines = sdp
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .toList();
    String? sessionAddress, address;
    List<String>? audio;
    final maps = <int, String>{};
    var inAudio = false, seenMedia = false;
    for (final line in lines) {
      if (line.startsWith('m=')) {
        seenMedia = true;
        if (audio != null && inAudio) break;
        inAudio = line.startsWith('m=audio ');
        if (inAudio) {
          audio = line.substring(8).split(RegExp(r'\s+'));
          address = sessionAddress;
        }
      } else if (line.startsWith('c=IN IP4 ') || line.startsWith('c=IN IP6 ')) {
        final host = line.substring(9);
        if (!seenMedia) sessionAddress = host;
        if (inAudio) address = host;
      } else if (inAudio && line.startsWith('a=rtpmap:')) {
        final match = RegExp(r'^a=rtpmap:([0-9]+) ([^ ]+)$').firstMatch(line);
        if (match != null) {
          maps[int.parse(match.group(1)!)] = match.group(2)!.toUpperCase();
        }
      }
    }
    final port = audio == null ? null : int.tryParse(audio.first);
    final host = address;
    if (audio == null ||
        audio.length < 3 ||
        audio[1] != 'RTP/AVP' ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        host == null ||
        !_ip(host)) {
      throw const SipLeaseFailure('INVALID_SDP');
    }
    final payloads = audio
        .skip(2)
        .map(int.tryParse)
        .whereType<int>()
        .where((value) => value >= 0 && value <= 127)
        .toList();
    bool matches(int payload, String codec) {
      final mapping = maps[payload];
      return mapping == '$codec/8000' ||
          mapping == '$codec/8000/1' ||
          (mapping == null &&
              ((payload == 0 && codec == 'PCMU') ||
                  (payload == 8 && codec == 'PCMA')));
    }

    final payload = payloads
        .where((value) => matches(value, 'PCMU') || matches(value, 'PCMA'))
        .firstOrNull;
    if (payload == null) throw const SipLeaseFailure('UNSUPPORTED_SDP_CODEC');
    final event = payloads
        .where(
          (value) =>
              maps[value] == 'TELEPHONE-EVENT/8000' ||
              maps[value] == 'TELEPHONE-EVENT/8000/1',
        )
        .firstOrNull;
    return SipAudioEndpoint(
      host,
      port,
      payload,
      matches(payload, 'PCMA') ? SipAudioCodec.pcma : SipAudioCodec.pcmu,
      event,
    );
  }

  static String offer(String localIp, int port) {
    if (!_ip(localIp) || port < 1 || port > 65535) {
      throw const SipLeaseFailure('INVALID_SDP');
    }
    final type = localIp.contains(':') ? 'IP6' : 'IP4';
    return [
      'v=0',
      'o=- 0 0 IN $type $localIp',
      's=PhoneAgent',
      'c=IN $type $localIp',
      't=0 0',
      'm=audio $port RTP/AVP 0 8 101',
      'a=rtpmap:0 PCMU/8000',
      'a=rtpmap:8 PCMA/8000',
      'a=rtpmap:101 telephone-event/8000',
      'a=fmtp:101 0-15',
      'a=sendrecv',
      '',
    ].join('\r\n');
  }

  static bool _ip(String value) {
    if (value.contains(':')) {
      final halves = value.split('::');
      if (halves.length > 2) return false;
      final groups = halves
          .expand((part) => part.isEmpty ? <String>[] : part.split(':'))
          .toList();
      return groups.every(
            (part) => RegExp(r'^[a-fA-F0-9]{1,4}$').hasMatch(part),
          ) &&
          (halves.length == 2 ? groups.length < 8 : groups.length == 8) &&
          value != '::';
    }
    final parts = value.split('.');
    return parts.length == 4 &&
        parts.every(
          (part) =>
              RegExp(r'^[0-9]{1,3}$').hasMatch(part) && int.parse(part) <= 255,
        ) &&
        value != '0.0.0.0';
  }
}
