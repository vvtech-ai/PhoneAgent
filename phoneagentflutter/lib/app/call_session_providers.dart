import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/account_session.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/calls/data/api_call_session_repository.dart';
import '../features/calls/domain/call_session.dart';
import 'business_providers.dart';

/// Loading a repository does not start polling, request a ticket or hang up.
/// The call-route coordinator must explicitly own a CallSessionController.
final callSessionRepositoryProvider =
    Provider.autoDispose<CallSessionRepository>((ref) {
      ref.watch(loginEpochProvider);
      final owner = ref.read(sessionControllerProvider.notifier).credentials;
      if (owner == null) throw ApiFailure.signedOut;
      return ApiCallSessionRepository(
        ref.watch(accountApiProvider),
        owner.accountId,
      );
    });
