// Synthetic external ports for the isolated auth preview and its UI tests.
// Not imported by any production entry point. No network or persistent storage.
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';

enum AuthScenarioKind { invitation, direct, saveFailure, restoreFailure }

class AuthScenario implements AuthGateway, SessionStore {
  AuthScenario(this.kind, {this.delay = Duration.zero});
  final AuthScenarioKind kind;
  final Duration delay;
  final submissions = <LoginSubmission>[];
  int sends = 0, reads = 0, writes = 0;
  AuthSession? saved;
  bool failSend = false;
  Future<void> Function()? beforeReply;

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    await beforeReply?.call();
  }

  @override
  Future<CodeDelivery> sendCode(String phone) async {
    sends++;
    await _wait();
    if (failSend) throw AuthFailure.network;
    return CodeDelivery(phone, 60);
  }

  @override
  Future<LoginOutcome> login(LoginSubmission submission) async {
    submissions.add(submission);
    await _wait();
    if (submission.loginChallenge == null && submission.code != '123456') {
      throw AuthFailure.incorrectCode;
    }
    if (kind == AuthScenarioKind.invitation) {
      if (submission.loginChallenge == null) {
        return LoginOutcome(
          phone: submission.phone,
          inviteRequired: true,
          loginChallenge: 'synthetic-challenge',
        );
      }
      if (submission.activationCode != 'DEMO') throw AuthFailure.invalidInvite;
    }
    return LoginOutcome(
      phone: submission.phone,
      inviteRequired: false,
      accountId: 'synthetic-preview',
      accessToken: 'synthetic-not-a-credential',
    );
  }

  @override
  Future<AuthSession?> read() async {
    reads++;
    if (kind == AuthScenarioKind.restoreFailure && reads == 1) {
      throw AuthFailure.storage;
    }
    return saved;
  }

  @override
  Future<void> write(AuthSession session) async {
    writes++;
    if (kind == AuthScenarioKind.saveFailure && writes == 1) {
      throw AuthFailure.storage;
    }
    saved = session;
  }

  @override
  Future<void> clear() async => saved = null;
}

class AuthPreviewHomeRepository implements HomeRepository {
  static const _home = HomeConfig('synthetic', [
    HomeSlogan('synthetic', 'MOCK 登录成功', '仅内存会话，刷新后重置'),
  ], []);
  @override
  Future<HomeConfig> load() async => _home;
  @override
  Future<HomeSlogan> nextSlogan(HomeConfig config) async =>
      config.slogans.first;
}

class AuthPreviewModelRepository implements CallModelRepository {
  @override
  Future<CallModelCatalog> load() async => const CallModelCatalog('', []);
  @override
  Future<CallModelCatalog> select(String provider) =>
      Future.error(UnsupportedError('Auth-only preview'));
  @override
  Future<CallVoiceCatalog> loadVoices(String provider) =>
      Future.error(UnsupportedError('Auth-only preview'));
  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) =>
      Future.error(UnsupportedError('Auth-only preview'));
}
