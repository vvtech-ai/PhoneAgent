import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/voice_clone/data/api_certified_recording_download.dart';
import '../features/voice_clone/data/certified_recording_repository.dart';
import '../features/voice_clone/data/device_certified_recording_store.dart';
import '../features/voice_clone/data/device_legacy_certified_recording_source.dart';
import '../features/voice_clone/data/migrating_certified_recording_store.dart';
import '../features/voice_clone/domain/certified_recording_store.dart';
import 'app_providers.dart';
import 'business_providers.dart';

final certifiedRecordingRepositoryProvider =
    Provider.autoDispose<CertifiedRecordingRepository>((ref) {
      // Retain the serial save/read boundary across navigation, not across accounts.
      ref.keepAlive();
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final config = ref.watch(appConfigProvider);
      final binding = jsonEncode([
        config.environment?.name,
        config.apiBaseUri?.toString(),
        owner?.accountId,
      ]);
      var alive = true;
      bool current() =>
          alive && owner != null && owner.sameLogin(session.credentials);
      CertifiedRecordingBlobStore blobs = DeviceCertifiedRecordingStore(
        CertifiedRecordingRepository.slot(binding),
      );
      if (owner != null &&
          DeviceLegacyCertifiedRecordingSource.eligible(config)) {
        blobs = MigratingCertifiedRecordingStore(
          target: blobs,
          binding: binding,
          isCurrent: current,
          readLegacy: DeviceLegacyCertifiedRecordingSource(
            config: config,
            accountId: owner.accountId,
          ).read,
        );
      }
      final repository = CertifiedRecordingRepository(
        binding: binding,
        diagnostics: ref.watch(accountApiProvider).diagnostics,
        blobs: blobs,
        downloads: ApiCertifiedRecordingDownload(ref.watch(accountApiProvider)),
        isCurrent: current,
      );
      ref.onDispose(() {
        alive = false;
        repository.close();
      });
      return repository;
    });

final prepareCertifiedRecordingClearProvider =
    Provider<Future<void> Function() Function()>((ref) {
      return () =>
          ref.read(certifiedRecordingRepositoryProvider).prepareClear();
    });
