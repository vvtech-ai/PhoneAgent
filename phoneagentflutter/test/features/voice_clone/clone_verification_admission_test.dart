import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification_admission.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_verification_repository.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';

import '../../support/synthetic_account_api.dart';

const _daily = '当前账号今日已发起7次人脸认证，已达每日7次上限（包含失败和未完成的认证），请明天再试';
const _cooldown = '当前账号人脸认证操作过于频繁，两次认证需间隔120秒，请在37秒后重试';

class _VerificationApi extends SyntheticAccountApi {
  String? message;
  String code = 'AC0001';
  Completer<void>? gate;
  final initEntered = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final init = request.path.endsWith('/init');
    if (init) {
      if (!initEntered.isCompleted) initEntered.complete();
      await gate?.future;
    }
    final denied = init && message != null;
    return ResponseBody.fromString(
      jsonEncode({
        'code': denied ? code : 0,
        if (denied) 'message': message,
        'data': request.path.endsWith('/replacement-check')
            ? {'replacementRequired': false}
            : {
                'attemptId': 'mock-attempt',
                'certifyId': 'mock-certify',
                'status': init ? 'INITIATED' : 'PASS',
                'scriptText': '合成文本',
                'expiresAt': '2099-01-01',
                'accepted': true,
              },
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

CloneFlowController _flow(_VerificationApi transport, PreviewCloneFlow ports) =>
    CloneFlowController(
      const CloneCreationLaunch(
        CloneCreationModel(
          cloneEntitled: true,
          pricePoints: 300,
          id: PreviewCloneFlow.model,
          name: 'Qwen',
        ),
        CloneCreationStart.authentication,
      ),
      CloneFlowServices(
        verification: ApiCloneVerificationRepository(
          transport.api,
          modelId: PreviewCloneFlow.model,
        ),
        candidates: ports.candidates,
        completion: ports,
        capture: () => ports.capture,
        player: ports,
        recordings: CloneFlowRecordings(
          read: ports.readRecording,
          save: ports.save,
          clear: ports.clear,
        ),
        points: () async => 900,
        verifiedName: () async => '',
        isCurrent: () => true,
        captureSupported: true,
      ),
    );

Future<void> _identity(CloneFlowController controller) async {
  controller.agree(true);
  await controller.next();
}

void main() {
  test(
    'completed daily notices retain configured limits and reject arbitrary text',
    () {
      for (final limit in [1, 7, 18, 25]) {
        for (final scope in ['当前账号', '同一身份（跨账号累计）']) {
          final message = '$scope今日已完成$limit次人脸认证，已达每日$limit次上限（含成功和失败），请明天再试';
          expect(
            CloneVerificationAdmissionFailure.parse(message)?.message,
            message,
          );
          expect(
            CloneVerificationAdmissionFailure.parse('$message extra'),
            isNull,
          );
        }
      }
    },
  );
  late _VerificationApi transport;
  late PreviewCloneFlow ports;
  late CloneFlowController controller;
  setUp(() {
    transport = _VerificationApi();
    ports = PreviewCloneFlow();
    controller = _flow(transport, ports);
  });
  tearDown(() {
    controller.dispose();
    transport.api.close();
  });

  for (final message in [
    _daily,
    _cooldown,
    '本次声音克隆仍在处理中，请稍后同步结果，勿重复认证。',
    _daily.replaceFirst('当前账号', '同一身份（跨账号累计）'),
    _cooldown.replaceFirst('当前账号', '同一身份（跨账号累计）'),
  ]) {
    test(
      'admission keeps identity and safe configured limit: $message',
      () async {
        transport.message = message;
        await _identity(controller);
        await controller.submitIdentity('演练用户', '000000200001010005');
        expect(controller.state.ui.step, CloneStep.identity);
        expect(controller.state.ui.error, message);
        expect(controller.state.ui.busy, isFalse);
        expect(ports.capture.captures, 0);
        expect(ports.candidates.fromVerified, 0);
        expect(
          transport.requests.where((r) => r.path.endsWith('/init')),
          hasLength(1),
        );
        await controller.synchronize();
        expect(
          transport.requests.where((r) => r.path.endsWith('/init')),
          hasLength(1),
        );

        transport.message = null;
        await controller.submitIdentity('演练用户', '000000200001010005');
        expect(controller.state.ui.step, CloneStep.candidate);
        expect(ports.capture.captures, 1);
        expect(
          transport.requests.where((r) => r.path.endsWith('/init')),
          hasLength(2),
        );
      },
    );
  }

  test('initialization pending stays on identity until confirmed', () async {
    transport.gate = Completer<void>();
    await _identity(controller);
    final pending = controller.submitIdentity('演练用户', '000000200001010005');
    await transport.initEntered.future;
    try {
      expect(controller.state.ui.step, CloneStep.identity);
      expect(controller.state.ui.busy, isTrue);
      expect(ports.capture.captures, 0);
    } finally {
      transport.gate!.complete();
    }
    await pending;
    expect(controller.state.ui.step, CloneStep.candidate);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform explains first Aliyun resource load while waiting', (
      tester,
    ) async {
      transport.gate = Completer<void>();
      await _identity(controller);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: CloneFlowPage(controller: controller),
        ),
      );
      final pending = controller.submitIdentity('演练用户', '000000200001010005');
      await tester.pump();
      expect(find.textContaining('首次加载认证资源可能需要十几秒'), findsOneWidget);
      transport.gate!.complete();
      await tester.pumpAndSettle();
      await pending;
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final message in [
    'private server detail token=synthetic',
    '$_daily\nprivate detail',
    _daily.replaceFirst('7次上限', '99999999999次上限'),
    _daily.replaceFirst('7次上限', '8次上限'),
    _cooldown.replaceFirst('37秒后', '121秒后'),
    _cooldown.replaceFirst('120秒', '0秒'),
    _cooldown.replaceFirst('当前账号', 'private identity'),
    '$_cooldown<script>',
  ]) {
    test('unknown or malformed init text remains generic: $message', () async {
      transport.message = message;
      await _identity(controller);
      await controller.submitIdentity('演练用户', '000000200001010005');
      expect(controller.state.ui.step, CloneStep.identity);
      expect(controller.state.ui.error, '认证初始化失败，请稍后重新认证。');
      expect(ports.capture.captures, 0);
    });
  }

  test('non-init callers still reject the same dynamic message', () async {
    transport.message = _daily;
    await expectLater(
      transport.api.request(
        'api/account/settings/voice-clone/verification/init',
        method: 'POST',
      ),
      throwsA(ApiFailure.rejected),
    );
  });

  testWidgets('denied init preserves entered form and allows explicit retry', (
    tester,
  ) async {
    transport.message = _cooldown;
    await _identity(controller);
    await tester.pumpWidget(
      MaterialApp(home: CloneFlowPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '演练用户');
    await tester.enterText(fields.at(1), '000000200001010005');
    final submit = find.text('开始人脸跟读认证');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(_cooldown), findsOneWidget);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, '演***');
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      '000***********0005',
    );
    expect(ports.capture.captures, 0);
    transport.message = null;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(controller.state.ui.step, CloneStep.candidate);
    expect(ports.capture.captures, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
