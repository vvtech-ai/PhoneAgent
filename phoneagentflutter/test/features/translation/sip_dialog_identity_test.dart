import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_dialog_identity.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_message.dart';

SipMessage bye({
  String from = '<sip:peer@example.test>;tag=remote',
  String to = '<sip:local@example.test>;tag=local',
  String cseq = '9 BYE',
  String extra = '',
  String id = 'synthetic',
}) => SipMessage.parse(
  'BYE sip:local@example.test SIP/2.0\r\nVia: SIP/2.0/UDP example.test;branch=z9hG4bK-peer\r\n'
  'From: $from\r\nTo: $to\r\nCall-ID: $id\r\nCSeq: $cseq\r\n$extra'
  'Content-Length: 0\r\n\r\n',
);
bool matches(
  SipMessage message, {
  String remote = '<sip:peer@example.test>;tag=remote',
}) => matchesSipDialogBye(
  message,
  callId: 'synthetic',
  localTag: 'local',
  remoteHeader: remote,
);

void main() {
  test(
    'reverses confirmed tags; URI and quoted display tag are not identity',
    () {
      expect(matches(bye()), true);
      expect(
        matches(
          bye(
            from:
                '"Display;tag=wrong" <sip:peer@example.test;tag=wrong>;TAG=remote',
          ),
        ),
        true,
      );
      expect(matches(bye(from: '<sip:peer@example.test>;tag=Remote')), false);
      expect(matches(bye(to: '<sip:local@example.test>;tag=wrong')), false);
      expect(matches(bye(id: 'other')), false);
    },
  );
  test(
    'duplicate/empty/quoted/unbalanced tags and identity headers refuse',
    () {
      for (final from in [
        '<sip:peer@example.test>;tag=remote;tag=wrong',
        '<sip:peer@example.test>;tag=remote;tag=',
        '<sip:peer@example.test>;tag="remote"',
        '"unclosed <sip:peer@example.test>;tag=remote',
        '<sip:peer@example.test;tag=remote',
      ]) {
        expect(matches(bye(from: from)), false, reason: from);
      }
      for (final extra in [
        'From: <sip:peer@example.test>;tag=remote\r\n',
        'To: <sip:local@example.test>;tag=local\r\n',
        'Call-ID: synthetic\r\n',
        'CSeq: 9 BYE\r\n',
      ]) {
        expect(matches(bye(extra: extra)), false);
      }
      for (final seq in [
        '0 BYE',
        '-1 BYE',
        '2147483648 BYE',
        '9 INFO',
        '9 extra BYE',
      ]) {
        expect(matches(bye(cseq: seq)), false);
      }
    },
  );
  test(
    'legacy absent remote tag is compatible only with a confirmed absent tag',
    () {
      final message = bye(from: '<sip:peer@example.test>');
      expect(matches(message), false);
      expect(matches(message, remote: '<sip:peer@example.test>'), true);
      expect(matches(message, remote: '<sip:peer@example.test>;tag='), false);
    },
  );
}
