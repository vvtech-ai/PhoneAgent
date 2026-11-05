import 'dart:async';
import 'dart:collection';
import 'package:phone_agent/features/translation/data/sip/md5_sip_authenticator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_message.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_request_builder.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_transactions.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_wire.dart';

class ScriptedWire implements SipWire {
  final sent = <String>[];
  final queue = Queue<SipMessage>();
  Completer<void>? waiting;
  void Function(SipMessage)? onSend;
  bool closed = false;
  void add(SipMessage message) {
    queue.add(message);
    if (waiting != null && !waiting!.isCompleted) waiting!.complete();
  }

  @override
  Future<void> send(String packet) async {
    if (closed) throw const SipLeaseFailure('WIRE_CLOSED');
    sent.add(packet);
    onSend?.call(SipMessage.parse(packet));
  }

  @override
  Future<SipMessage?> receive(Duration timeout) async {
    if (queue.isEmpty && !closed) {
      waiting = Completer<void>();
      await Future.any([waiting!.future, Future<void>.delayed(timeout)]);
      waiting = null;
    }
    return queue.isEmpty ? null : queue.removeFirst();
  }

  @override
  Future<void> close() async {
    closed = true;
    waiting?.complete();
  }
}

SipMessage response(
  SipMessage request,
  int status, {
  String body = '',
  String extra = '',
  String? id,
  String? via,
}) => SipMessage.parse(
  'SIP/2.0 $status Synthetic\r\nVia: ${via ?? request.header('via')}\r\nCall-ID: ${id ?? request.header('call-id')}\r\nCSeq: ${request.header('cseq')}\r\nTo: ${request.header('to')};tag=remote\r\n$extra'
  'Content-Length: ${body.length}\r\n\r\n$body',
);

void main() {
  late ScriptedWire wire;
  late SipTransactions tx;
  late List<SipCallPhase> phases;
  const lease = SipLease(
    id: 'synthetic',
    accountId: 'synthetic',
    server: 'example.test',
    port: 5060,
    transport: 'UDP',
    username: 'synthetic',
    password: 'synthetic',
    callerNumber: '1001',
  );
  setUp(() {
    wire = ScriptedWire();
    phases = [];
    var token = 0;
    tx = SipTransactions(
      authenticator: const Md5SipAuthenticator(),
      builder: SipRequestBuilder(
        lease: lease,
        target: '13800138000',
        localIp: '192.0.2.1',
        localSipPort: 5062,
        localRtpPort: 4000,
        callId: 'synthetic@phoneagent',
        fromTag: 'synthetic',
      ),
      wire: wire,
      onPhase: phases.add,
      token: () => 'synthetic-${token++}',
    );
  });
  List<SipMessage> sent(String method) => wire.sent
      .map(SipMessage.parse)
      .where((message) => message.method == method)
      .toList();
  void connected(SipMessage message) => wire.add(
    response(
      message,
      200,
      body: SipSdp.offer('192.0.2.2', 4002),
      extra: 'Contact: <sip:peer@192.0.2.2>\r\n',
    ),
  );
  test(
    'REGISTER and INVITE challenges use bounded new CSeq, wrong session ignored',
    () async {
      var registers = 0, invites = 0;
      wire.onSend = (message) {
        if (message.method == 'REGISTER') {
          wire.add(
            response(
              message,
              ++registers == 1 ? 401 : 200,
              extra: registers == 1
                  ? 'WWW-Authenticate: Digest realm="synthetic", nonce="synthetic", qop="auth"\r\n'
                  : '',
            ),
          );
        } else if (message.method == 'INVITE') {
          if (++invites == 1) {
            wire.add(
              response(
                message,
                407,
                extra:
                    'Proxy-Authenticate: Digest realm="synthetic", nonce="synthetic"\r\n',
              ),
            );
          } else {
            wire.add(response(message, 200, id: 'other-session'));
            wire.add(response(message, 180));
            connected(message);
          }
        }
      };
      final endpoint = await tx.start();
      expect(endpoint.port, 4002);
      expect(phases, [
        SipCallPhase.registering,
        SipCallPhase.dialing,
        SipCallPhase.ringing,
        SipCallPhase.connected,
      ]);
      expect(sent('REGISTER').map((message) => message.cseq), [1, 2]);
      expect(sent('INVITE').map((message) => message.cseq), [1, 2]);
      expect(sent('INVITE').last.header('proxy-authorization'), isNotNull);
      expect(sent('ACK'), hasLength(2));
      await tx.close();
      expect(sent('BYE'), hasLength(1));
    },
  );
  test(
    'cancel race acknowledges late 200 then BYE without connected media',
    () async {
      final invited = Completer<SipMessage>();
      wire.onSend = (message) {
        if (message.method == 'REGISTER') wire.add(response(message, 200));
        if (message.method == 'INVITE') invited.complete(message);
      };
      final start = tx.start();
      final invite = await invited.future;
      await tx.hangup();
      connected(invite);
      await expectLater(start, throwsA(isA<SipLeaseFailure>()));
      expect(phases, isNot(contains(SipCallPhase.connected)));
      expect(sent('CANCEL'), hasLength(1));
      expect(sent('CANCEL').single.header('via'), invite.header('via'));
      expect(sent('CANCEL').single.header('to'), invite.header('to'));
      expect(sent('ACK'), hasLength(1));
      expect(sent('BYE'), hasLength(1));
      await tx.close();
      expect(sent('BYE'), hasLength(1));
    },
  );
  test('busy response ACKs transaction without cancel or new INVITE', () async {
    wire.onSend = (message) {
      if (message.method == 'REGISTER') wire.add(response(message, 200));
      if (message.method == 'INVITE') wire.add(response(message, 486));
    };
    await expectLater(
      tx.start(),
      throwsA(
        isA<SipLeaseFailure>().having(
          (value) => value.code,
          'code',
          'INVITE_486',
        ),
      ),
    );
    expect(sent('INVITE'), hasLength(1));
    expect(sent('ACK'), hasLength(1));
    expect(sent('CANCEL'), isEmpty);
    await tx.close();
  });
  test(
    'DTMF waits remote acknowledgement; remote BYE stops without echo BYE',
    () async {
      wire.onSend = (message) {
        if (message.method == 'REGISTER') wire.add(response(message, 200));
        if (message.method == 'INVITE') connected(message);
        if (message.method == 'INFO') wire.add(response(message, 200));
      };
      await tx.start();
      final hold = tx.holdUntilEnded();
      await tx.sendDtmf('1');
      wire.add(
        SipMessage.parse(
          'BYE sip:local@192.0.2.1 SIP/2.0\r\nVia: synthetic\r\nFrom: <sip:peer@example.test>;tag=remote\r\nTo: <sip:local@192.0.2.1>;tag=synthetic\r\nCall-ID: synthetic@phoneagent\r\nCSeq: 9 BYE\r\nContent-Length: 0\r\n\r\n',
        ),
      );
      await hold;
      expect(phases.last, SipCallPhase.ended);
      expect(sent('BYE'), isEmpty);
      await tx.close();
    },
  );
  test(
    'UDP retransmission preserves transaction instead of making a new call',
    () async {
      var registers = 0;
      wire.onSend = (message) {
        if (message.method == 'REGISTER' && ++registers == 2) {
          wire.add(response(message, 200));
        }
        if (message.method == 'INVITE') connected(message);
      };
      await tx.start();
      expect(wire.sent[0], wire.sent[1]);
      expect(sent('INVITE'), hasLength(1));
      await tx.close();
    },
  );
  test(
    'old top Via branch cannot ring, finish REGISTER or confirm INFO',
    () async {
      const wrongVia = 'SIP/2.0/UDP 192.0.2.1:5062;branch=z9hG4bK-stale';
      SipMessage? info;
      wire.onSend = (message) {
        if (message.method == 'REGISTER') {
          wire.add(response(message, 403, via: wrongVia));
          wire.add(response(message, 200));
        }
        if (message.method == 'INVITE') {
          wire.add(response(message, 180, via: wrongVia));
          wire.add(response(message, 486, via: wrongVia));
          connected(message);
        }
        if (message.method == 'INFO') {
          info = message;
          wire.add(response(message, 200, via: wrongVia));
        }
      };
      await tx.start();
      expect(phases, isNot(contains(SipCallPhase.ringing)));
      final hold = tx.holdUntilEnded();
      var acknowledged = false;
      final command = tx.sendDtmf('2').then((_) {
        acknowledged = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(acknowledged, isFalse);
      wire.add(response(info!, 200));
      await command;
      expect(acknowledged, isTrue);
      await tx.hangup();
      await hold;
      await tx.close();
    },
  );
  test(
    'wrong dialog BYE replies 481 and keeps current call until a valid BYE',
    () async {
      wire.onSend = (message) {
        if (message.method == 'REGISTER') wire.add(response(message, 200));
        if (message.method == 'INVITE') connected(message);
      };
      await tx.start();
      SipMessage bye(
        String from,
        String to, {
        String id = 'synthetic@phoneagent',
      }) => SipMessage.parse(
        'BYE sip:local@192.0.2.1 SIP/2.0\r\nVia: synthetic\r\n'
        'From: <sip:peer@example.test>;tag=$from\r\nTo: <sip:local@192.0.2.1>;tag=$to\r\n'
        'Call-ID: $id\r\nCSeq: 9 BYE\r\nContent-Length: 0\r\n\r\n',
      );
      wire.add(bye('wrong', 'synthetic'));
      wire.add(bye('remote', 'wrong'));
      wire.add(bye('remote', 'synthetic', id: 'other'));
      wire.onSend = (message) {
        if (message.status == 481) {
          expect(phases.last, SipCallPhase.connected);
          final rejected = wire.sent
              .map(SipMessage.parse)
              .where((p) => p.status == 481)
              .length;
          if (rejected == 3) wire.add(bye('remote', 'synthetic'));
        }
      };
      await tx.holdUntilEnded();
      expect(
        wire.sent.map(SipMessage.parse).where((p) => p.status == 481),
        hasLength(3),
      );
      expect(phases.where((p) => p == SipCallPhase.ended), hasLength(1));
      expect(sent('BYE'), isEmpty);
      await tx.close();
      expect(sent('BYE'), isEmpty);
    },
  );
  test(
    'original SDP failure survives a failed BYE and cleanup stays unconfirmed',
    () async {
      wire.onSend = (message) {
        if (message.method == 'REGISTER') wire.add(response(message, 200));
        if (message.method == 'INVITE') {
          wire.add(response(message, 200, body: 'invalid SDP'));
        }
        if (message.method == 'BYE') {
          throw const SipLeaseFailure('SYNTHETIC_BYE_SEND_FAILED');
        }
      };
      await expectLater(
        tx.start(),
        throwsA(
          isA<SipLeaseFailure>().having(
            (v) => v.code,
            'original error',
            'INVALID_SDP',
          ),
        ),
      );
      await expectLater(
        tx.close(),
        throwsA(
          isA<SipLeaseFailure>().having(
            (v) => v.code,
            'cleanup error',
            'SIP_CLEANUP_UNCONFIRMED',
          ),
        ),
      );
      expect(wire.closed, isTrue);
      expect(sent('BYE'), hasLength(1));
    },
  );
  test(
    'failed CANCEL still waits for late INVITE cleanup before closing wire',
    () async {
      final invited = Completer<SipMessage>();
      wire.onSend = (message) {
        if (message.method == 'REGISTER') wire.add(response(message, 200));
        if (message.method == 'INVITE') invited.complete(message);
        if (message.method == 'CANCEL') {
          throw const SipLeaseFailure('SYNTHETIC_CANCEL_SEND_FAILED');
        }
      };
      final start = tx.start();
      final observed = expectLater(
        start,
        throwsA(
          isA<SipLeaseFailure>().having(
            (v) => v.code,
            'cancel error',
            'CANCELLED',
          ),
        ),
      );
      final invite = await invited.future;
      final closed = expectLater(
        tx.close(),
        throwsA(
          isA<SipLeaseFailure>().having(
            (v) => v.code,
            'cleanup error',
            'SIP_CLEANUP_UNCONFIRMED',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(wire.closed, isFalse);
      connected(invite);
      await observed;
      await closed;
      expect(wire.closed, isTrue);
      expect(sent('ACK'), hasLength(1));
      expect(sent('BYE'), hasLength(1));
    },
  );
}
