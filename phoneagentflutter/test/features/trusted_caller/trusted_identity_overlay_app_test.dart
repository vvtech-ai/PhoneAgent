import 'package:phone_agent/features/trusted_caller/data/device_trusted_identity_display_port.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_identity_credentials_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/trusted_identity_presentation_payload.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_identity_overlay_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/trusted_identity_overlay');
  testWidgets(
    'display engine reuses page, updates and closes current identity only',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      Future<void> update(String id, String name) async {
        final payload = TrustedIdentityPresentationPayload.encode(
          TrustedIncomingIdentity(
            owner: const TrustedCallerOwner('synthetic', '12345678901', 1),
            eventId: id,
            name: name,
            caller: '10987654321',
            target: '12345678901',
            sequence: 'synthetic',
            verification: TrustedIdentityVerification.pending,
          ),
          'test',
        );
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('update', payload),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        TrustedIdentityOverlayApp(port: DeviceTrustedIdentityDisplayPort()),
      );
      await tester.pump();
      expect(calls.first.method, 'ready');
      await update('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '展示A');
      expect(find.text('展示A'), findsOneWidget);
      final oldBack = tester
          .widget<TrustedIdentityCredentialsPage>(
            find.byType(TrustedIdentityCredentialsPage),
          )
          .onBack;
      await update('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '展示B');
      expect(find.text('展示A'), findsNothing);
      expect(find.text('展示B'), findsOneWidget);
      oldBack();
      await tester.pump();
      expect(calls.last.arguments, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      await tester.tap(find.byType(InkWell).last);
      await tester.pump();
      expect(calls.last.method, 'dismiss');
      expect(calls.last.arguments, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(calls.where((call) => call.method == 'rendered').length, 2);
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    },
  );
}
