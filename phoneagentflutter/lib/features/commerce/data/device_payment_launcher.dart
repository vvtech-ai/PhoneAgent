import 'package:flutter/services.dart';
import 'commerce_diagnostics.dart';
import '../domain/payment_launcher.dart';
import '../domain/commerce_repository.dart';

class DevicePaymentLauncher
    implements PaymentLauncher, AppleTransactionUpdates {
  const DevicePaymentLauncher({
    this.channel = const MethodChannel('phone_agent/commerce_payment'),
    this.diagnostics,
  });
  final MethodChannel channel;
  final CommerceDiagnostics? diagnostics;
  static final Stream<void> _transactions = const EventChannel(
    'phone_agent/commerce_transactions',
  ).receiveBroadcastStream().map((_) {});
  @override
  Stream<void> get transactionUpdates => _transactions;

  @override
  Future<void> acknowledge(NativePaymentResult result) async {
    if (result.transactionId != null) {
      await channel.invokeMethod<void>('acknowledge', {
        'transactionId': result.transactionId,
      });
    }
  }

  @override
  Future<bool> available() async {
    try {
      final available = await channel.invokeMethod<bool>('available') == true;
      diagnostics?.availability(available);
      return available;
    } on MissingPluginException catch (error) {
      diagnostics?.event(
        CommerceStage.availability,
        DiagnosticResult.failed,
        error: error,
      );
      return false;
    } on PlatformException catch (error) {
      diagnostics?.event(
        CommerceStage.availability,
        DiagnosticResult.failed,
        error: error,
      );
      return false;
    }
  }

  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) =>
      diagnostics?.run(CommerceStage.products, () => _products(ids)) ??
      _products(ids);

  Future<Map<String, PlatformProduct>> _products(Set<String> ids) async {
    if (!await available() || ids.isEmpty) return {};
    final values = await channel.invokeListMethod<Object?>('products', {
      'ids': ids.toList(),
    });
    if (values == null) {
      throw const FormatException('Missing platform products');
    }
    final result = <String, PlatformProduct>{};
    for (final value in values) {
      if (value is! Map ||
          value['id'] is! String ||
          value['displayPrice'] is! String ||
          (value['displayPrice'] as String).trim().isEmpty) {
        throw const FormatException('Invalid platform product');
      }
      final id = value['id'] as String;
      if (ids.contains(id)) {
        for (final key in ['price', 'currencyCode', 'productType']) {
          if (value[key] != null && value[key] is! String) {
            throw const FormatException('Invalid platform price');
          }
        }
        result[id] = PlatformProduct(
          id,
          value['displayPrice'] as String,
          price: value['price'] as String?,
          currencyCode: value['currencyCode'] as String?,
          productType: value['productType'] as String?,
        );
      }
    }
    diagnostics?.event(
      CommerceStage.products,
      DiagnosticResult.received,
      requested: ids.length,
      found: result.length,
    );
    return Map.unmodifiable(result);
  }

  NativePaymentResult _result(Object? value) {
    if (value is! Map) throw const FormatException('Invalid payment result');
    final status = value['nativeResultStatus'];
    if (status != null &&
        (status is! String || !RegExp(r'^[0-9]{4}$').hasMatch(status))) {
      throw const FormatException('Invalid native payment status');
    }
    final outcome = switch (value['nativeOutcome']) {
      null => null,
      'CANCELED' => NativePaymentOutcome.canceled,
      'PENDING' => NativePaymentOutcome.pending,
      _ => throw const FormatException('Invalid native payment outcome'),
    };
    return NativePaymentResult(
      transactionId: value['transactionId'] as String?,
      signedTransaction: value['signedTransaction'] as String?,
      appAccountToken: value['appAccountToken'] as String?,
      platformProductId: value['platformProductId'] as String?,
      nativeResultStatus: status as String?,
      nativeOutcome: outcome,
    );
  }

  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    if (!await available()) throw const PaymentUnavailable();
    final clock = Stopwatch()..start();
    try {
      return _result(
        await channel.invokeMethod<Object?>('launch', {
          'channel': material.channel,
          'orderNo': material.orderNo,
          'parameters': material.parameters,
        }),
      );
    } on PlatformException catch (error) {
      diagnostics?.event(
        CommerceStage.nativePurchase,
        DiagnosticResult.failed,
        orderNo: material.orderNo,
        error: error,
        elapsedMs: clock.elapsedMilliseconds,
      );
      if (error.code == 'PRICE_CHANGED') {
        throw const CommerceFailure('APPLE_PRICE_CHANGED');
      }
      rethrow;
    }
  }

  @override
  Future<List<NativePaymentResult>> restore() async {
    if (!await available()) return [];
    final clock = Stopwatch()..start();
    try {
      final results = await channel.invokeListMethod<Object?>('restore');
      if (results?.isNotEmpty == true) {
        diagnostics?.event(
          CommerceStage.nativeRestore,
          DiagnosticResult.received,
          found: results!.length,
          elapsedMs: clock.elapsedMilliseconds,
        );
      }
      return List.unmodifiable((results ?? []).map(_result));
    } catch (error) {
      diagnostics?.event(
        CommerceStage.nativeRestore,
        DiagnosticResult.failed,
        error: error,
        elapsedMs: clock.elapsedMilliseconds,
      );
      rethrow;
    }
  }
}
