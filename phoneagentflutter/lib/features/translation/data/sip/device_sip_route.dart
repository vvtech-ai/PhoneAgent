import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/sip/sip_lease.dart';

class SipDeviceRoute {
  const SipDeviceRoute(this.localAddress, this.peerAddress);
  final String localAddress, peerAddress;
}

class DeviceSipRouteResolver {
  const DeviceSipRouteResolver({
    this.channel = const MethodChannel('phone_agent/sip_route'),
    this.platform,
    this.web,
  });
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  Future<SipDeviceRoute> resolve(SipLease lease) async {
    if ((web ?? kIsWeb) ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(platform ?? defaultTargetPlatform)) {
      throw const SipLeaseFailure('SIP_ROUTE_UNAVAILABLE');
    }
    try {
      final value = await channel
          .invokeMapMethod<String, Object?>('resolve', {
            'host': lease.server,
            'port': lease.port,
          })
          .timeout(const Duration(seconds: 5));
      final local = value?['localAddress'], peer = value?['peerAddress'];
      if (local is! String || peer is! String) {
        throw const FormatException();
      }
      final a = InternetAddress.tryParse(local),
          b = InternetAddress.tryParse(peer);
      if (a == null ||
          b == null ||
          a.type != b.type ||
          a.isMulticast ||
          b.isMulticast ||
          const {'0.0.0.0', '::'}.contains(a.address) ||
          const {'0.0.0.0', '::'}.contains(b.address)) {
        throw const FormatException();
      }
      return SipDeviceRoute(a.address, b.address);
    } catch (_) {
      throw const SipLeaseFailure('SIP_ROUTE_UNAVAILABLE');
    }
  }
}
