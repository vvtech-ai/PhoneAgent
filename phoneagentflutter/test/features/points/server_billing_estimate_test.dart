import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/data/api_points_billing.dart';
import 'package:phone_agent/features/points/domain/points_presentation.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'estimate follows published rate and missing or invalid rate hides estimate',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      final api = ApiPointsBilling(http.api);
      http.data = {'billingBasePointsPerMinute': 250};
      expect(
        PointsPresentation.estimatedMinutes(
          1234,
          pointsPerMinute: await api.load(),
        ),
        4,
      );
      for (final rate in [null, 0, -1]) {
        http.data = {'billingBasePointsPerMinute': rate};
        expect(
          PointsPresentation.estimatedMinutes(
            1234,
            pointsPerMinute: await api.load(),
          ),
          isNull,
        );
      }
      expect(
        http.requests.first.uri.path,
        '/api/points/global-config/published',
      );
      expect(http.requests.first.headers['Authorization'], 'Bearer synthetic');
    },
  );
}
