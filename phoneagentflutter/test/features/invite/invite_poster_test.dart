import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_poster.dart';
import 'invite_fakes.dart';

void main() {
  testWidgets('poster produces a real PNG for the current invitation', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => InvitePosterPainter(sampleActivity, sampleCode).render(),
    );
    expect(bytes, isNotNull);
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    if (const bool.fromEnvironment('CAPTURE_INVITE_POSTER')) {
      final file = File('.local/invite-validation/poster.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    }
  });
}
