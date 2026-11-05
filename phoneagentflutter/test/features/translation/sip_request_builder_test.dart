import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_message.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_request_builder.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';

void main() {
  const lease = SipLease(
    id: 'synthetic',
    accountId: 'synthetic',
    server: 'sip.example.test',
    port: 5060,
    transport: 'UDP',
    username: 'synthetic',
    password: 'synthetic-private',
    callerNumber: '1001',
  );
  late SipRequestBuilder builder;
  setUp(
    () => builder = SipRequestBuilder(
      lease: lease,
      target: '13800138000',
      localIp: '192.0.2.1',
      localSipPort: 5062,
      localRtpPort: 4000,
      callId: 'synthetic@phoneagent',
      fromTag: 'synthetic',
    ),
  );
  test(
    'native REGISTER/INVITE have consistent IDs, SDP and no plaintext password',
    () {
      final register = SipMessage.parse(
        builder.register(branch: 'z9hG4bK-synthetic', cseq: 1),
      );
      expect(register.method, 'REGISTER');
      expect(register.header('expires'), '300');
      final wire = builder.invite(branch: 'z9hG4bK-synthetic', cseq: 2);
      final invite = SipMessage.parse(wire);
      expect(invite.method, 'INVITE');
      expect(invite.header('call-id'), register.header('call-id'));
      expect(invite.cseq, 2);
      expect(SipSdp.parse(invite.body).port, 4000);
      expect(wire, isNot(contains(lease.password)));
    },
  );
  test(
    'CANCEL reuses invite branch and CSeq; dialog uses reversed route set',
    () {
      final response = SipMessage.parse(
        'SIP/2.0 200 OK\r\nTo: <sip:peer@example.test>;tag=remote\r\nContact: <sip:peer@192.0.2.2>\r\nRecord-Route: <sip:first.example.test;lr>, <sip:second.example.test;lr>\r\nContent-Length: 0\r\n\r\n',
      );
      final dialog = builder.dialogFrom(response, 2);
      expect(dialog.routes, [
        'sip:second.example.test;lr',
        'sip:first.example.test;lr',
      ]);
      final ack = SipMessage.parse(
        builder.dialog('ACK', dialog, branch: 'z9hG4bK-new', cseq: 2),
      );
      expect(ack.startLine, 'ACK sip:peer@192.0.2.2 SIP/2.0');
      expect(ack.header('to'), contains('tag=remote'));
      final cancel = SipMessage.parse(
        builder.cancel(
          branch: 'z9hG4bK-invite',
          inviteCseq: 2,
          toHeader: dialog.toHeader,
        ),
      );
      expect(cancel.header('via'), contains('branch=z9hG4bK-invite'));
      expect(cancel.cseqMethod, 'CANCEL');
      expect(cancel.cseq, 2);
      final info = SipMessage.parse(
        builder.dialog(
          'INFO',
          dialog,
          branch: 'z9hG4bK-dtmf',
          cseq: 3,
          digit: '#',
        ),
      );
      expect(info.body, 'Signal=#\r\nDuration=160\r\n');
    },
  );
  test(
    'remote OPTIONS response preserves Via set; header injection rejected',
    () {
      final request = SipMessage.parse(
        'OPTIONS sip:local@example.test SIP/2.0\r\nVia: first\r\nVia: second\r\nCall-ID: synthetic\r\nCSeq: 1 OPTIONS\r\nContent-Length: 0\r\n\r\n',
      );
      expect(
        SipMessage.parse(SipRequestBuilder.ok(request)).headerValues('via'),
        ['first', 'second'],
      );
      expect(
        () => builder.register(
          branch: 'z9hG4bK-x',
          cseq: 1,
          authorization: 'Authorization: value\r\nInjected: yes',
        ),
        throwsA(isA<SipLeaseFailure>()),
      );
      expect(
        () => builder.dialog(
          'BYE',
          const SipDialog(
            toHeader: 'synthetic',
            inviteCseq: 1,
            requestUri: 'sips:peer@example.test',
          ),
          branch: 'z9hG4bK-x',
          cseq: 2,
        ),
        throwsA(isA<SipLeaseFailure>()),
      );
    },
  );
}
