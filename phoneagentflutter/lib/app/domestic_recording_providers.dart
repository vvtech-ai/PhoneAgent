import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/translation/data/recording/device_domestic_recording_encoder.dart';
import '../features/translation/data/recording/private_domestic_recording_files.dart';
import 'app_providers.dart';
import 'business_providers.dart';

final domesticRecordingEncoderProvider =
    Provider<DeviceDomesticRecordingEncoder>(
      (ref) => const DeviceDomesticRecordingEncoder(),
    );
final domesticRecordingFilesProvider = Provider<PrivateDomesticRecordingFiles?>(
  (ref) {
    if (kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return null;
    }
    ref.watch(loginEpochProvider);
    final session = ref.watch(sessionControllerProvider.notifier);
    final owner = session.credentials;
    final config = ref.watch(appConfigProvider);
    if (owner == null ||
        config.environment == null ||
        config.apiBaseUri == null) {
      return null;
    }
    final encoder = ref.watch(domesticRecordingEncoderProvider);
    var active = true;
    ref.onDispose(() => active = false);
    return PrivateDomesticRecordingFiles(
      environment: config.environment!.name,
      apiBase: config.apiBaseUri.toString(),
      accountId: owner.accountId,
      root: () async => Directory(await encoder.privateRoot()),
      isCurrent: () => active && owner.sameLogin(session.credentials),
    );
  },
);
