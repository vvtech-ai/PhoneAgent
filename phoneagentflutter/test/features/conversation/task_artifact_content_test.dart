import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/conversation/data/artifacts/api_task_artifact_repository.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import '../../support/synthetic_account_api.dart';

class _Download extends AccountApi {
  _Download()
    : super(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/',
        ),
        SyntheticAccountApi(),
      );
  String content = '';
  @override
  Future<Uint8List> download(
    String path, {
    required int maxBytes,
    required Set<String> mediaTypes,
    Map<String, String>? query,
  }) async => Uint8List.fromList(utf8.encode(content));
}

void main() {
  test(
    'CSV JSON and HTML error bodies never reach the file destination',
    () async {
      final api = _Download();
      const artifact = TaskArtifact(
        id: 'batch-receipt-csv.cw.Yg',
        kind: TaskArtifactKind.batchCsv,
        fileName: '合成.csv',
        mimeType: 'text/csv',
        status: 'READY',
      );
      final repository = ApiTaskArtifactRepository(api);
      for (final content in [
        '{"code":"FAIL","message":"secret"}',
        '\uFEFF  {"code":1}',
        '<html>Error</html>',
      ]) {
        api.content = content;
        await expectLater(
          repository.download(artifact),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      api.content = 'name,status\n合成,SUCCESS';
      expect(utf8.decode(await repository.download(artifact)), api.content);
      api.close();
    },
  );
}
