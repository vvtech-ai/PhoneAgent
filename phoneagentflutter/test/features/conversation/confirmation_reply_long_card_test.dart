import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/confirmation/api_call_confirmation_reply_repository.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';

import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'long card still submits its exact identity and a bounded context hint',
    () async {
      final fixture = SyntheticAccountApi()
        ..data = {'decision': 'CONFIRM', 'answer': ''};
      addTearDown(fixture.api.close);
      final reply = await ApiCallConfirmationReplyRepository(fixture.api)
          .classify((
            accountId: 'synthetic',
            sessionId: 'session',
            toolId: 'long-card-tool',
            specSignature: 'full-spec-signature',
            generation: 1,
            cardText: '详细任务内容' * 400,
          ), '确定。');
      expect(reply.decision, CallReplyDecision.confirm);
      final body = fixture.requests.single.data as Map;
      expect(body['pendingToolCallId'], 'long-card-tool');
      expect(body['userText'], '确定。');
      expect((body['cardText'] as String).length, lessThanOrEqualTo(1500));
    },
  );
}
