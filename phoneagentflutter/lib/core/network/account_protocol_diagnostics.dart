import 'dart:convert';
import 'package:flutter/foundation.dart';

void accountProtocolMetadata(Uri uri, int? status, Object? payload) {
  assert(() {
    if (!const bool.fromEnvironment('ENABLE_INVITE_PROTOCOL_DIAGNOSTICS')) {
      return true;
    }
    const paths = {
      'api/invite/me/code',
      'api/invite/me/records',
      'api/invite/activity',
      'api/commerce/catalog',
      'api/membership/current',
      'api/commerce/orders',
    };
    if (!paths.any((path) => uri.path.endsWith('/$path'))) return true;
    const codes = {
      'INVALID_CODE',
      'INVITE_INVALID',
      'INVITE_CODE_FORMAT_INVALID',
      'INVITE_NOT_FOUND',
      'CONFIG_SYNC_PENDING',
      'CONFIG_SYNCING',
      'CONFIG_NOT_PUBLISHED',
      'EXTERNAL_INVITE_UNAVAILABLE',
      'CHANNEL_UNAVAILABLE',
      'PRODUCT_UNAVAILABLE',
      'MEMBERSHIP_ORDER_EXISTS',
      'AGREEMENT_REQUIRED',
    };
    final root = payload is Map ? payload : null;
    final data = root?['data'];
    final error = data is Map ? data['errorCode'] : null;
    final rootCode = root?['code'];
    debugPrint(
      'ACCOUNT_PROTOCOL_META ${jsonEncode({'path': uri.path, 'httpStatus': status, 'apiCode': rootCode is int || rootCode == '000000' ? rootCode : (codes.contains(rootCode) ? rootCode : 'OTHER'), 'errorCode': error == null ? null : (codes.contains(error) ? error : 'OTHER'), 'payloadIsMap': root != null})}',
    );
    return true;
  }());
}
