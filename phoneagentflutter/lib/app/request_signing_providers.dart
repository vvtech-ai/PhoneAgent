import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/signing/c1_transport.dart';
import '../core/network/signing/device_c1_credentials.dart';

/// Installation context survives token refresh and account switches.
final requestSigningProvider = Provider<C1Transport>(
  (_) => C1Transport(DeviceC1Credentials()),
);
