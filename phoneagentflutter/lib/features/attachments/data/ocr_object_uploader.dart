import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/account_session.dart';

/// Presigned object storage transport. Never shares account interceptors.
class OcrObjectUploader {
  OcrObjectUploader({Dio? client}) : _client = client ?? Dio() {
    _client.options.connectTimeout = const Duration(seconds: 8);
  }
  final Dio _client;
  void close() => _client.close(force: true);

  Future<void> put(Uri uri, String contentType, Uint8List bytes) async {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ApiFailure.invalidResponse;
    }
    try {
      final response = await _client.putUri<ResponseBody>(
        uri,
        data: Stream.value(bytes),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.stream,
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      await response.data?.stream.listen((_) {}).cancel();
      if ((response.statusCode ?? 500) < 200 ||
          (response.statusCode ?? 500) >= 300) {
        throw ApiFailure.rejected;
      }
    } on DioException {
      throw ApiFailure.network;
    }
  }
}
