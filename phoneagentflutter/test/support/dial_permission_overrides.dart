import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/dial_permission_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';
import 'package:phone_agent/features/translation/data/preview_translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';

/// Route tests explicitly assume granted location; denial has its own suite.
List<Override> grantedDialPermissionOverrides() {
  final location = _ImmediateLocation();
  return [
    dialPermissionPortProvider.overrideWithValue(
      PreviewDialPermissionPort(supportsCallLog: false)
        ..grant = DialPermissionGrant.granted,
    ),
    dialPermissionMemoryProvider.overrideWithValue(DialPermissionMemory()),
    translationLocationSourceProvider.overrideWithValue(location),
    translationLocationStoreProvider.overrideWithValue(location),
  ];
}

class _ImmediateLocation extends PreviewTranslationLocation {
  @override
  Future<TranslationLocationResult> locate() async {
    requests++;
    return result;
  }
}
