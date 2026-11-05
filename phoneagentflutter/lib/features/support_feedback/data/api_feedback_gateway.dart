import 'package:dio/dio.dart';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../domain/feedback.dart';

class ApiFeedbackGateway implements FeedbackGateway {
  ApiFeedbackGateway(this.api);
  final AccountApi api;
  @override
  Future<void> submit(FeedbackRequest request) async {
    final form = FormData.fromMap({
      'requestId': request.requestId,
      'description': request.description,
      'contact': request.contact,
      'includeLogs': '${request.logs != null}',
      if (request.deviceInfo.isNotEmpty) 'deviceInfo': request.deviceInfo,
      for (var i = 0; i < request.images.length; i++)
        'image$i': MultipartFile.fromBytes(
          request.images[i].bytes,
          filename: request.images[i].fileName,
          contentType: DioMediaType.parse(request.images[i].mediaType),
        ),
      if (request.logs case final logs?)
        'log': MultipartFile.fromBytes(
          logs.bytes,
          filename: logs.fileName,
          contentType: DioMediaType('application', 'zip'),
        ),
    });
    final receipt = AccountApi.object(
      await api.request('api/feedback', method: 'POST', body: form),
    );
    if (receipt['id'] is! String ||
        (receipt['id'] as String).isEmpty ||
        receipt['feedbackNo'] is! String ||
        (receipt['feedbackNo'] as String).isEmpty ||
        receipt['requestId'] != request.requestId ||
        receipt['submittedAt'] is! String ||
        DateTime.tryParse(receipt['submittedAt'] as String) == null ||
        receipt['imageCount'] != request.images.length ||
        receipt['hasLogs'] != (request.logs != null)) {
      throw ApiFailure.invalidResponse;
    }
  }
}
