import 'package:flutter_test/flutter_test.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  for (final path in [
    'api/assistant/realtime/call/session/status',
    'api/assistant/realtime/call/hangup',
    'api/agent-calls/monitor/token',
    'api/agent-calls/synthetic/evaluation',
    'api/agent-calls/synthetic/recording',
    'api/agent-calls/batches/synthetic/evaluation',
  ]) {
    test('$path carries the bound account token', () async {
      final server = SyntheticAccountApi();
      addTearDown(server.api.close);
      await server.api.request(path);
      expect(
        server.requests.single.headers['Authorization'],
        'Bearer synthetic',
      );
    });
  }
}
