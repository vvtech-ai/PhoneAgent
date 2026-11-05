import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/ocr_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/attachments/domain/ocr_image_source.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';
import '../../support/call_admission_fixture.dart';
import '../../support/synthetic_account_api.dart';

class _CancelledPicker implements OcrImageSource {
  int picks = 0;
  @override
  Future<SelectedOcrImage?> pick() async {
    picks++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'formal apology provider waits for environment and preserves OCR lifetime',
    () async {
      final api = SyntheticAccountApi();
      final picker = _CancelledPicker();
      const entry = ConversationEntry(
        sessionId: 'synthetic-apology-entry',
        skillId: 'apology_master',
      );
      final container = ProviderContainer(
        overrides: [
          accountApiProvider.overrideWithValue(api.api),
          networkAvailabilityEventsProvider.overrideWithValue(
            const NoNetworkAvailabilityEvents(),
          ),
          sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
          ocrImageSourceProvider.overrideWithValue(picker),
          currentAccountIdProvider.overrideWithValue('synthetic'),
          agentGatewayProvider.overrideWithValue(OfflineAgent()),
          historyRepositoryProvider.overrideWithValue(OfflineHistory()),
          taskErrorStatusSyncProvider.overrideWith((ref) {
            final sync = PreviewTaskErrorStatusPorts().createSync();
            ref.onDispose(sync.close);
            return sync;
          }),
          callAdmissionProvider(
            entry.sessionId,
          ).overrideWithValue(AdmissionFixture().service),
          callSessionRepositoryProvider.overrideWithValue(
            PreviewCallFlow(CallFlowScenario.single),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        api.api.close();
      });
      container.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(loginEpochProvider), isNotNull);
      final keep = container.listen(
        conversationControllerProvider(entry),
        (_, __) {},
      );
      addTearDown(keep.close);
      final state = container.read(conversationControllerProvider(entry));
      expect(
        state.messages.any((m) => m.text.contains('道歉需要使用您的克隆音色')),
        isFalse,
      );
      expect(state.activeOptionsId, isNull);
      final controller = container.read(
        conversationControllerProvider(entry).notifier,
      );
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(picker.picks, 1, reason: 'OCR is active once its owner is ready');
      controller.close();
      await controller.attachments!.pick(controller.ocrBoundary.sourceAnchor);
      expect(picker.picks, 1, reason: 'closed owner must still block OCR');
    },
  );
}
