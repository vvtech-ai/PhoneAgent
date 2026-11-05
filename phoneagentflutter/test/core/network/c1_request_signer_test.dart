import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/signing/c1_request_signer.dart';
import 'package:phone_agent/core/network/signing/c1_signed_url.dart';

void main() {
  test('matches the current Java SDK public Android C1 vector', () {
    const context =
        'eyJhcHBWZXJzaW9uQ29kZSI6MzgsImFwcFZlcnNpb25OYW1lIjoiMS4wLjM4Iiwic2RrVmVyc2lvbk5hbWUiOiIxLjAuMCIsIm9zTmFtZSI6IkFuZHJvaWQiLCJvc1ZlcnNpb24iOiIxNCIsImRldmljZUJyYW5kIjoi5rWL6K-V5ZOB54mMIiwiZGV2aWNlTW9kZWwiOiJGaXh0dXJlIiwibmV0d29ya1R5cGUiOiJXSUZJIn0';
    String sign(String body) => C1RequestSigner.sign(
      method: 'POST',
      uri: Uri.parse('https://example.test/api/auth/sms/login'),
      requestId: '00000001-1111-4111-8111-111111111111',
      timestamp: 1789084800000,
      deviceId: '33333333-3333-4333-8333-333333333333',
      apiKey: 'fixture-app',
      secret: 'PUBLIC-FIXTURE-SECRET-NOT-FOR-RUNTIME',
      clientContext: context,
      accessToken: '',
      body: utf8.encode(body),
    );
    const expected =
        'df2c1c2bda690cf9646509764ce8418519289f0c5582a9a0ccf999d07d35f7ff';
    expect(sign('{"phone":"13800000000","code":"123456"}'), expected);
    expect(sign('{}'), isNot(expected));
  });

  test('SM3 known answer and strict canonical query/path', () {
    expect(
      C1RequestSigner.digest(utf8.encode('abc')),
      '66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0',
    );
    expect(
      C1SignedUrl.query('z=%E4%B8%AD&a=two%20words&a=1'),
      'a=1&a=two%20words&z=%E4%B8%AD',
    );
    expect(C1SignedUrl.path('/api/%E4%B8%AD'), '/api/%E4%B8%AD');
    for (final path in ['/api//x', '/api/%2e%2e', '/api/a%2fb', '/api/%FF']) {
      expect(() => C1SignedUrl.path(path), throwsFormatException);
    }
    expect(() => C1SignedUrl.query('a=two+words'), throwsFormatException);
    expect(
      C1SignedUrl.withQuery(Uri.parse('https://example.test/api'), {
        'q': 'two words',
      }).query,
      'q=two%20words',
    );
  });
}
