import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invite.dart';
import '../../domain/invite_welcome_failure.dart';

class InviteWelcomeState {
  const InviteWelcomeState({
    this.loading = false,
    this.points,
    this.error = '',
    this.canContinue = false,
  });
  final bool loading, canContinue;
  final int? points;
  final String error;
}

class InviteWelcomeController extends StateNotifier<InviteWelcomeState> {
  InviteWelcomeController(
    this.resolver,
    this.code, {
    this.allowBusinessFailure = true,
  }) : super(const InviteWelcomeState());
  final InviteResolver resolver;
  final String code;
  final bool allowBusinessFailure;
  Future<void> load() async {
    if (state.loading) return;
    state = const InviteWelcomeState(loading: true);
    try {
      final points = await resolver.resolve(code);
      if (mounted) {
        state = InviteWelcomeState(points: points, canContinue: true);
      }
    } catch (e) {
      if (mounted) {
        state = InviteWelcomeState(
          error: inviteWelcomeFailureMessage(
            e is InviteFailure ? e.code : 'UNKNOWN',
            allowBusinessFailure: allowBusinessFailure,
          ),
          canContinue:
              e is InviteFailure &&
              inviteWelcomeCanContinue(
                e.code,
                allowBusinessFailure: allowBusinessFailure,
              ),
        );
      }
    }
  }
}
