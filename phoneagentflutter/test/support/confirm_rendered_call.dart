import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';

/// Explicit fixture rendering/intent, never used by product code.
void markCallCardPresented(ConversationController controller) {
  final request = controller.calls?.snapshot.launch.request;
  if (request != null) {
    controller.reportConfirmationPresented(
      request.identity,
      request.specSignature,
    );
  }
}

void confirmRenderedCall(ConversationController controller) {
  markCallCardPresented(controller);
  expect(controller.send('确认拨打'), isTrue);
}
