import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../core/network/account_session.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/auth/data/device_legacy_session_source.dart';
import '../features/calls/data/device_legacy_call_admission_source.dart';
import '../features/calls/data/api_call_admission_notice_repository.dart';
import '../features/calls/data/secure_call_admission_notice_store.dart';
import '../features/calls/domain/call_admission_service.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'points_providers.dart';
import 'task_call_model_providers.dart';

final legacyCallAdmissionSourceProvider =
    Provider<DeviceLegacyCallAdmissionSource?>((ref) {
      if (kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android ||
          !DeviceLegacySessionSource.eligible(ref.watch(appConfigProvider))) {
        return null;
      }
      return const DeviceLegacyCallAdmissionSource();
    });

final callAdmissionProvider = Provider.autoDispose
    .family<CallAdmissionService, String>((ref, sessionId) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      if (owner == null) throw ApiFailure.signedOut;
      final config = ref.watch(appConfigProvider);
      final legacy = ref.watch(legacyCallAdmissionSourceProvider);
      var active = true;
      bool current() => active && owner.sameLogin(session.credentials);
      ref.onDispose(() {
        active = false;
      });
      final api = ref.watch(accountApiProvider);
      // Retain sources without rebuilding the conversation on each state update.
      final wallet = ref.watch(pointsWalletControllerProvider.notifier);
      ref.watch(callModelControllerProvider.notifier);
      final taskModel = ref.watch(taskCallModelSourceProvider(sessionId));
      return CallAdmissionService(
        store: SecureCallAdmissionNoticeStore(
          environment: '${config.environment?.name}|${config.apiBaseUri}',
          accountId: owner.accountId,
          isCurrent: current,
          legacyRead: legacy == null
              ? null
              : (id, aliases) => legacy.read(owner.accountId, id, aliases),
        ),
        notices: ApiCallAdmissionNoticeRepository(api),
        readBalance: () =>
            ref.read(pointsWalletControllerProvider).admissionBalance,
        readModel: () => taskModel
            .resolve(ref.read(callModelControllerProvider).catalog)
            ?.name,
        modelAvailable: () {
          final models = ref.read(callModelControllerProvider);
          return !models.loading &&
              !models.saving &&
              taskModel.resolve(models.catalog) != null;
        },
        refreshBalance: () async {
          try {
            return await wallet.refreshBalance();
          } on ApiFailure catch (error) {
            if (error == ApiFailure.signedOut ||
                error == ApiFailure.sessionChanged) {
              rethrow;
            }
            return null;
          }
        },
      );
    });
