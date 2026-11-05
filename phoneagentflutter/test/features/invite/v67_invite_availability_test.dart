import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'invite_fakes.dart';

void main() {
  test(
    'account replacement hides previous activity during pending reload',
    () async {
      final epoch = StateProvider<int>((ref) => 1);
      final repo = FakeInviteRepository();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          inviteRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        inviteEntryPresentationProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      await container.read(inviteAvailabilityProvider.future);
      expect(container.read(inviteEntryPresentationProvider)?.visible, true);
      repo.delayed = Completer();
      container.read(epoch.notifier).state = 2;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(inviteEntryPresentationProvider), isNull);
      repo.delayed!.complete(const InviteOverview(null, null));
      await container.read(inviteAvailabilityProvider.future);
      expect(container.read(inviteEntryPresentationProvider)?.visible, false);
    },
  );
}
