import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../support/synthetic_account_api.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'membership_contract_v2_test.dart' show fixture;

/// Scripted HTTP boundary; all API decoding and purchase state stay production.
class CommerceRecoveryTransport extends SyntheticAccountApi {
  int creates = 0, materials = 0, quotes = 0;
  int quoteStatus = 200, queryStatus = 200;
  String? errorCode;
  String? errorPath;
  int? overrideStatus;
  bool networkFailure = false;
  String nextType = 'renew';
  String payment = 'SUCCEEDED', fulfillment = 'SUCCEEDED';
  String firstType = 'new';
  final requestIds = <String>[];
  final materialOrders = <String>[];
  final quotedLevels = <String, String>{};
  String? pending;

  Map<String, Object?> order(String id, {bool creating = false}) => {
    ...orderJson(),
    if (!creating && payment == 'SUCCEEDED' && fulfillment == 'SUCCEEDED')
      ...fixture('result-${id == 'order-1' ? firstType : nextType}'),
    'orderNo': id,
    'quoteId': 'quote-$creates',
    'membershipLevel': quotedLevels['quote-${id.split('-').last}'] ?? 'BASIC',
    'membershipMonths': 1,
    'paymentState': creating ? 'PENDING' : payment,
    'fulfillmentState': creating ? 'NOT_STARTED' : fulfillment,
    'appState': creating
        ? 'PENDING_PAYMENT'
        : payment != 'SUCCEEDED'
        ? 'PAYING'
        : fulfillment != 'SUCCEEDED'
        ? 'CREDITING'
        : 'COMPLETED',
    'cashAmountFen': 4000,
    'cashPaidFen': !creating && payment == 'SUCCEEDED' ? 4000 : 0,
    'expiresAt': '2099-01-01T00:00:00+08:00',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    await beforeResponse?.call(request);
    final path = request.uri.path;
    Object? response;
    var status = 200;
    if (path.endsWith('/catalog')) {
      response = {
        'configVersionId': 1,
        'revisionNo': 1,
        'agreementVersion': 'v1',
        'agreementUrl': 'https://example.test/terms',
        'supportEmail': '',
        'benefitsByLevel': <String, Object?>{},
        'products': [
          for (final level in ['BASIC', 'PLUS', 'PREMIUM'])
            {
              'productId': level,
              'name': '月卡',
              'productType': 'MEMBERSHIP',
              'level': level,
              'months': 1,
              'cashAmountFen': 4000,
              'basePoints': 0,
              'bonusPoints': 0,
              'currency': 'CNY',
              'channel': 'ALIPAY',
              'available': true,
            },
        ],
      };
    } else if (path.endsWith('/membership/current')) {
      response = {
        'level': 'BASIC',
        'terms': [],
        'benefits': <String, Object?>{},
        'pendingOrderNo': pending,
      };
    } else if (path.endsWith('/quotes')) {
      quotes++;
      status = quoteStatus;
      final body = request.data as Map;
      final type = creates == 0 ? firstType : nextType;
      final template = fixture('quote-$type');
      final preview = template['membershipPreview'] as Map;
      final level = body['productId'] as String;
      quotedLevels['quote-${creates + 1}'] = level;
      response = {
        ...template,
        'membershipPreview': {
          ...preview,
          'targetLevel': level,
          if (type == 'renew')
            'precedingEntitlements': [
              for (final item in preview['precedingEntitlements'] as List)
                {...item as Map, 'level': level},
            ],
        },
        'quoteId': 'quote-${creates + 1}',
        'productId': body['productId'],
        'configVersionId': 1,
        'cashAmountFen': 4000,
        'currency': 'CNY',
        'expiresAt': '2099-01-01T00:00:00+08:00',
      };
    } else if (path.endsWith('/payment')) {
      materials++;
      final id = path.split('/').reversed.skip(1).first;
      materialOrders.add(id);
      response = {
        'orderNo': id,
        'channel': 'ALIPAY',
        'expiresAt': '2099-01-01T00:00:00+08:00',
        'parameters': {'signedOrder': 'private-signature'},
      };
    } else if (path.endsWith('/orders') && request.method == 'POST') {
      creates++;
      requestIds.add((request.data as Map)['requestId'] as String);
      response = order('order-$creates', creating: true);
    } else if (path.endsWith('/orders')) {
      response = {'items': <Object?>[], 'page': 0, 'totalPages': 0};
    } else if (path.contains('/orders/')) {
      status = queryStatus;
      response = order(path.split('/').last);
    } else {
      throw StateError('Unexpected synthetic request: $path');
    }
    if (networkFailure) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': errorPath == null || path.endsWith(errorPath!)
            ? errorCode ?? '000000'
            : '000000',
        'message': 'private-provider-body token phone signature',
        'data': response,
      }),
      overrideStatus ?? status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
