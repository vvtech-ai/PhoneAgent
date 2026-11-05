import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';

// Retain only for this workbench login, not for the lifetime of a settings page.
// No credentials, production client or persistent storage belong in this port.
final _outboundPreviewProvider = Provider<PreviewOutboundNumberRepository>((
  ref,
) {
  ref.watch(loginEpochProvider);
  return PreviewOutboundNumberRepository();
});

List<Override> shellSettingsOverrides() => [
  outboundNumberRepositoryProvider.overrideWith(
    (ref) => ref.watch(_outboundPreviewProvider),
  ),
];
