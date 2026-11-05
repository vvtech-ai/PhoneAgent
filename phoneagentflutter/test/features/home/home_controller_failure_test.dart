import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/domain/home_defaults.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';

class FailingHome implements HomeRepository {
  bool fail = true;
  @override
  Future<HomeConfig> load() async {
    if (fail) throw StateError('offline');
    return builtinHome;
  }

  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async =>
      config.slogans.first;
}

void main() {
  test('failure releases loading and retry retains usable entries', () async {
    final repository = FailingHome(), owner = HomeController(FailingHome());
    owner.dispose();
    final c = HomeController(repository);
    await c.refresh();
    expect(c.state.loading, false);
    repository.fail = false;
    await c.refresh();
    expect(c.state.config.cards, isNotEmpty);
    expect(c.state.slogan, isNotNull);
    c.dispose();
  });
}
