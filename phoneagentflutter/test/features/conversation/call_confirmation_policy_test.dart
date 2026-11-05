import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';

void main() {
  test(
    'v66 explicit replies include natural affirmative phrases after a displayed card',
    () {
      for (final text in ['确认拨打', '好，确认拨打。', '好的', '没问题', '就直接打吧']) {
        expect(
          CallConfirmationPolicy.classify(text),
          CallConfirmationIntent.confirm,
          reason: text,
        );
      }
    },
  );
  test(
    'editing, cancellation, questions and conditions override affirmation',
    () {
      for (final text in [
        '确认拨打，但是改成明天',
        '好的，先不要打',
        '现在拨打吗？',
        '如果可以就确认拨打',
        '确认，等一下',
      ]) {
        expect(
          CallConfirmationPolicy.classify(text),
          CallConfirmationIntent.continueConversation,
          reason: text,
        );
      }
      expect(
        CallConfirmationPolicy.classify('随便'),
        CallConfirmationIntent.ambiguous,
      );
      expect(CallConfirmationPolicy.noEditAnswer('没有要改的'), isTrue);
      expect(CallConfirmationPolicy.editOrCancel('没有要改的'), isFalse);
      expect(CallConfirmationPolicy.editOrCancel('没有要改的，但是号码修改一下'), isTrue);
    },
  );
}
