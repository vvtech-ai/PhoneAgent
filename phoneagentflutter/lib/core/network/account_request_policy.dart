import 'account_session.dart';

void validateAccountRequest(
  String path,
  String method,
  String? key,
  bool standardKey,
  int? clonePricePoints,
) {
  if (key != null &&
      (method != 'POST' ||
          !RegExp(
            standardKey
                ? r'^[A-Za-z0-9_:-]{1,128}$'
                : r'^[A-Za-z0-9_-]{1,128}$',
          ).hasMatch(key))) {
    throw ApiFailure.invalidResponse;
  }
  if (clonePricePoints != null &&
      (clonePricePoints <= 0 ||
          clonePricePoints > 9223372036854775807 ||
          method != 'POST' ||
          !RegExp(
            r'^api/account/settings/voice-clone/models/[A-Za-z0-9_-]+/candidates/(from-recording|from-verification/[A-Za-z0-9_-]+)$',
          ).hasMatch(path))) {
    throw ApiFailure.invalidResponse;
  }
}
