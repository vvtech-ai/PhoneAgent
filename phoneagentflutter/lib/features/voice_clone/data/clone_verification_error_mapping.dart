import '../../../core/network/account_session.dart';
import '../domain/clone_verification_admission.dart';
import 'clone_error_mapping.dart';

/// PARAM_INVALID shares AC0001 with signing errors: accept only known limits.
String? cloneVerificationErrorMessage(Object? code, Object? message) =>
    code == 'AC0001'
    ? CloneVerificationAdmissionFailure.parse(message)?.message
    : null;

Future<T> cloneVerificationRequest<T>(Future<T> Function() send) async {
  try {
    return await cloneRequest(send);
  } on ApiCodeFailure catch (error) {
    final failure = CloneVerificationAdmissionFailure.parse(error.code);
    if (failure != null) throw failure;
    rethrow;
  }
}
