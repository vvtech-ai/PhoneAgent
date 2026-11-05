import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/network/account_session.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/support_feedback/data/api_feedback_gateway.dart';
import '../features/support_feedback/data/feedback_image_picker.dart';
import '../features/support_feedback/data/feedback_image_processor.dart';
import '../features/support_feedback/presentation/feedback_controller.dart';
import '../features/support_feedback/presentation/feedback_state.dart';
import '../features/app_logs/domain/format_device_environment.dart';
import 'business_providers.dart';
import 'diagnostics_providers.dart';
import 'log_report_providers.dart';

final feedbackImagePickerProvider = Provider(
  (_) => FeedbackImagePicker(ImagePicker(), FeedbackImageProcessor()),
);

final supportFeedbackProvider =
    StateNotifierProvider.autoDispose<FeedbackController, FeedbackState>((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      if (owner == null) throw ApiFailure.signedOut;
      final environment = ref.watch(deviceEnvironmentSourceProvider);
      return FeedbackController(
        gateway: ApiFeedbackGateway(ref.watch(accountApiProvider)),
        logs: ref.watch(logReportRepositoryProvider),
        current: () => owner.sameLogin(session.credentials),
        deviceInfo: () async {
          final metadata = await environment.read();
          if (!owner.sameLogin(session.credentials)) {
            throw ApiFailure.sessionChanged;
          }
          return formatDeviceEnvironment(metadata);
        },
      );
    });
