import 'package:phone_agent/features/translation/data/sip/md5_sip_authenticator.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_message.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';

void main() {
  test(
    'top Via branch respects compact header, first hop and rejects duplicate empty parameter',
    () {
      SipMessage packet(String via) => SipMessage.parse(
        'SIP/2.0 200 Synthetic\r\nv: $via\r\nContent-Length: 0\r\n\r\n',
      );
      expect(
        packet(
          'SIP/2.0/UDP 192.0.2.1;branch=z9hG4bK-first, SIP/2.0/UDP 192.0.2.2;branch=other',
        ).topViaBranch,
        'z9hG4bK-first',
      );
      expect(
        packet('SIP/2.0/UDP 192.0.2.1;BrAnCh = z9hG4bK-Case').topViaBranch,
        'z9hG4bK-Case',
      );
      expect(
        packet(
          'SIP/2.0/UDP 192.0.2.1;branch=z9hG4bK-first;branch=',
        ).topViaBranch,
        isNull,
      );
      expect(
        packet(
          'SIP/2.0/UDP 192.0.2.1, SIP/2.0/UDP 192.0.2.2;branch=other',
        ).topViaBranch,
        isNull,
      );
    },
  );

  String wire(
    String headers, {
    String body = '',
    String status = 'SIP/2.0 200 OK',
  }) =>
      '$status\r\n$headers\r\nContent-Length: ${utf8.encode(body).length}\r\n\r\n$body';
  test('SIP compact/repeated/folded headers and UTF8 body preserved', () {
    final message = SipMessage.parse(
      wire(
        'v: first\r\nVia: second\r\ni: synthetic\r\nCSeq: 2 INVITE\r\nSubject: hello\r\n world',
        body: '合成',
      ),
    );
    expect(message.headerValues('via'), ['first', 'second']);
    expect(message.header('call-id'), 'synthetic');
    expect(message.header('subject'), 'hello world');
    expect(message.body, '合成');
    expect(message.cseq, 2);
    expect(message.cseqMethod, 'INVITE');
    expect(
      SipMessage.parse(
        wire('CSeq: 2 BYE', status: 'BYE sip:peer@example.test SIP/2.0'),
      ).method,
      'BYE',
    );
  });
  test('truncated and duplicate lengths rejected without response text', () {
    for (final raw in [
      'SIP/2.0 200 OK\r\nContent-Length: 2\r\n\r\nx',
      wire('Content-Length: 0'),
      'not SIP\r\n\r\n',
    ]) {
      expect(() => SipMessage.parse(raw), throwsA(isA<SipLeaseFailure>()));
    }
  });
  test(
    'Digest qop auth matches known RFC2617 vector; quoted comma preserved',
    () {
      final message = SipMessage.parse(
        wire(
          'WWW-Authenticate: Digest realm="testrealm@host.com", qop="auth,auth-int", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"',
          status: 'SIP/2.0 401 Unauthorized',
        ),
      );
      final challenge = SipDigestChallenge.fromMessage(message);
      final authorization = challenge.authorization(
        username: 'Mufasa',
        password: 'Circle Of Life',
        method: 'GET',
        uri: '/dir/index.html',
        cnonce: '0a4f113b',
      );
      expect(
        authorization,
        contains('response="6629fae49393a05397450978507c4ef1"'),
      );
      expect(authorization, contains('nc=00000001'));
      expect(challenge.toString(), isNot(contains('dcd98')));
    },
  );
  test('unsupported Digest algorithm or qop fails instead of guessing', () {
    for (final suffix in ['algorithm=SHA-256', 'qop="auth-int"']) {
      final challenge = SipDigestChallenge.fromMessage(
        SipMessage.parse(
          wire(
            'Proxy-Authenticate: Digest realm="synthetic", nonce="synthetic", $suffix',
            status: 'SIP/2.0 407 Proxy Authentication Required',
          ),
        ),
      );
      expect(
        () => challenge.authorization(
          username: 'synthetic',
          password: 'synthetic',
          method: 'INVITE',
          uri: 'sip:example.test',
          cnonce: 'synthetic',
        ),
        throwsA(isA<SipLeaseFailure>()),
      );
    }
  });
  test('SDP chooses offered supported codec and audio-scoped address', () {
    final endpoint = SipSdp.parse(
      'v=0\r\nc=IN IP4 192.0.2.1\r\nm=video 9999 RTP/AVP 96\r\nc=IN IP4 192.0.2.2\r\nm=audio 4000 RTP/AVP 111 98 101\r\nc=IN IP4 192.0.2.3\r\na=rtpmap:111 opus/48000/2\r\na=rtpmap:98 PCMA/8000\r\na=rtpmap:101 telephone-event/8000\r\n',
    );
    expect(endpoint.address, '192.0.2.3');
    expect(endpoint.payloadType, 98);
    expect(endpoint.codec, SipAudioCodec.pcma);
    expect(endpoint.telephoneEventPayload, 101);
    expect(
      SipSdp.parse(SipSdp.offer('2001:db8::1', 5000)).address,
      '2001:db8::1',
    );
  });
  test(
    'SDP rejects unknown codec, wrong sample rate, malformed address and zero port',
    () {
      for (final body in [
        'c=IN IP4 192.0.2.1\r\nm=audio 4000 RTP/AVP 111\r\na=rtpmap:111 opus/48000/2',
        'c=IN IP4 192.0.2.1\r\nm=audio 4000 RTP/AVP 0\r\na=rtpmap:0 PCMU/16000',
        'c=IN IP4 999.2.3.4\r\nm=audio 4000 RTP/AVP 0',
        'c=IN IP4 192.0.2.1\r\nm=audio 0 RTP/AVP 0',
      ]) {
        expect(() => SipSdp.parse(body), throwsA(isA<SipLeaseFailure>()));
      }
    },
  );
}
