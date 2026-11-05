import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/tasks/data/api_task_detail_repository.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'legacy detail uses current backend contract and bearer request',
    () async {
      final wire = SyntheticAccountApi()
        ..data = {
          'taskId': 'legacy',
          'originText': '预订',
          'status': 'FAILED',
          'finalResult': '未接通',
          'createdAt': '2026-10-08',
          'slot': {'partySize': 3, 'reservationTime': '明晚'},
          'selectedRestaurant': {'name': '合成餐厅'},
          'callRecords': [
            {
              'callId': 'call',
              'status': 'ENDED',
              'result': 'FAILED',
              'summary': '未接通',
            },
          ],
        };
      final result = await ApiTaskDetailRepository(wire.api).load('legacy');
      expect(result.status, 'FAILED');
      expect(result.fields['人数'], '3');
      expect(result.fields['选定餐厅'], '合成餐厅');
      expect(result.calls.single.callId, 'call');
      expect(wire.requests.single.uri.path, '/api/task/detail/legacy');
      expect(wire.requests.single.headers['Authorization'], 'Bearer synthetic');
    },
  );
  test(
    'invalid path and mismatched response cannot become restored identity',
    () async {
      final wire = SyntheticAccountApi()..data = {'taskId': 'another'};
      final repo = ApiTaskDetailRepository(wire.api);
      await expectLater(
        repo.load('../bad'),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(wire.requests, isEmpty);
      await expectLater(
        repo.load('legacy'),
        throwsA(ApiFailure.invalidResponse),
      );
    },
  );
}
