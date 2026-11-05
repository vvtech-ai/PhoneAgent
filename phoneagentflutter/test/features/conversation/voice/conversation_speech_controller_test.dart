import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';

class SpeechFake implements ReplySpeechPlayback {
  final sentences = <String>[];
  @override
  ReplySpeechPhase phase = ReplySpeechPhase.accepting;
  @override
  bool synthesizing = false;
  @override
  bool hasPendingText = false;
  @override
  int queuedBytes = 0;
  @override
  int failures = 0;
  @override
  bool enqueue(String text) {
    sentences.add(text);
    return true;
  }

  @override
  void complete() {
    phase = ReplySpeechPhase.draining;
  }

  @override
  Future<void> cancel() async {
    phase = ReplySpeechPhase.cancelled;
  }
}

void main() {
  late ConversationSpeechController speech;
  late List<SpeechFake> players;
  late bool allowed;
  setUp(() {
    allowed = true;
    players = [];
    speech = ConversationSpeechController(
      enabled: () => allowed,
      factory: (_, __) {
        final p = SpeechFake();
        players.add(p);
        return p;
      },
    );
  });
  tearDown(() => speech.dispose());
  void delta(String value) =>
      speech.accept(AgentEvent(AgentEventKind.text, text: value));
  test('new entry narrates once and interruption never replays it', () async {
    speech.speakOpening('请告诉我需求。');
    speech.speakOpening('请告诉我需求。');
    expect(players.single.sentences, ['请告诉我需求。']);
    await speech.interrupt();
    speech.speakOpening('请告诉我需求。');
    expect(players, hasLength(1));
  });
  test('restored, muted and already started turns never narrate opening', () {
    speech.speakOpening('历史开场。', restored: true);
    expect(players, isEmpty);
    allowed = false;
    speech.speakOpening('关闭播报。');
    allowed = true;
    speech.speakOpening('关闭后打开不重放。');
    expect(players, isEmpty);
    speech.begin();
    speech.speakOpening('新轮已开始。');
    expect(players, isEmpty);
    delta('仍能播报当前回复。');
    expect(players.single.sentences, ['仍能播报当前回复。']);
  });
  test('first unpunctuated segment queues within 800ms of first delta', () {
    fakeAsync((time) {
      delta('半句');
      time.elapse(const Duration(milliseconds: 300));
      delta('后半');
      time.elapse(const Duration(milliseconds: 300));
      delta('收尾');
      time.elapse(const Duration(milliseconds: 199));
      expect(players, isEmpty);
      time.elapse(const Duration(milliseconds: 1));
      expect(players.single.sentences, ['半句后半收尾']);

      delta('结束');
      speech.finish();
      expect(players.single.sentences, ['半句后半收尾', '结束']);
      expect(players.single.phase, ReplySpeechPhase.draining);
      time.elapse(const Duration(seconds: 1));
      expect(players.single.sentences, ['半句后半收尾', '结束']);
    });
  });
  test('timed partial emphasis queues only its speakable words', () {
    fakeAsync((time) {
      delta('**重要');
      time.elapse(const Duration(milliseconds: 300));
      delta('内容');
      time.elapse(const Duration(milliseconds: 500));
      expect(players.single.sentences, ['重要内容']);
    });
  });
  test('fenced code with a newline never reaches speech', () {
    fakeAsync((time) {
      delta('```secret\nmore code');
      expect(players, isEmpty);
      time.elapse(const Duration(milliseconds: 800));
      expect(players, isEmpty);
      delta('\n```\n可播。');
      expect(players.single.sentences, ['可播。']);
    });
  });
  test('prose before an open code fence still queues at 800ms', () {
    fakeAsync((time) {
      delta('可播正文');
      time.elapse(const Duration(milliseconds: 300));
      delta('```secret');
      time.elapse(const Duration(milliseconds: 500));
      expect(players.single.sentences, ['可播正文']);
      time.elapse(const Duration(milliseconds: 100));
      delta('```后续');
      time.elapse(const Duration(milliseconds: 800));
      expect(players.single.sentences, ['可播正文', '后续']);
    });
  });
  test('partial Markdown link never sends its URL to speech', () {
    fakeAsync((time) {
      delta('参考[文档](https://secret');
      time.elapse(const Duration(milliseconds: 800));
      expect(players.single.sentences, ['参考文档']);
      delta('.example)后续');
      time.elapse(const Duration(milliseconds: 800));
      expect(players.single.sentences, ['参考文档', '后续']);
    });
  });
  test('nested link label never exposes its destination', () {
    delta('参考[外层 [内层]](https://secret.example)后续。');
    expect(players.single.sentences, ['参考外层 内层后续。']);
  });
  test('nested Markdown links keep both destinations out of speech', () {
    delta('参考[外层 [内层](https://inner.test)](https://outer.test)后续。');
    expect(players.single.sentences, ['参考外层 内层后续。']);
  });
  test('parentheses inside a link destination do not expose its tail', () {
    delta('参考[文档](https://x.test/a_(b)/secret)后续。');
    expect(players.single.sentences, ['参考文档后续。']);
  });
  test('a shorter tick run inside a four tick fence stays silent', () {
    delta('````\nsecret\n```\nprivate\n````\n可播。');
    expect(players.single.sentences, ['可播。']);
  });
  test('ticks inside a code line cannot close a multiline fence', () {
    delta('````\nA ```` B\nC\n````\n可播。');
    expect(players.single.sentences, ['可播。']);
  });
  test('a fence-looking code line with trailing text stays inside code', () {
    delta('````\n````not a close\nsecret\n````\n可播。');
    expect(players.single.sentences, ['可播。']);
  });
  test('trailing spaces on a closing fence do not swallow later prose', () {
    delta('```\n代码\n```   \n后续正文。');
    expect(players.single.sentences, ['后续正文。']);
  });
  test('ordinary bracketed text after a spoken exclamation is not lost', () {
    delta('注意!');
    expect(players.single.sentences, ['注意!']);
    delta('[请确认]。');
    expect(players.single.sentences, ['注意!', '请确认。']);
  });
  test('a split image does not narrate its alt text or destination', () {
    delta('图!');
    expect(players.single.sentences, ['图!']);
    delta('[图片](https://secret.example)后续。');
    expect(players.single.sentences, ['图!', '后续。']);
  });
  test('an unfinished image label still obeys the reply size limit', () {
    delta('图!');
    delta('[${'字' * 65537}');
    speech.finish();
    expect(players.single.sentences, hasLength(1));
  });
  test(
    'split code fence ignores inner punctuation and resets on next turn',
    () {
      fakeAsync((time) {
        delta('`');
        delta('``internal.\nnext!');
        time.elapse(const Duration(milliseconds: 800));
        expect(players, isEmpty);
        speech.finish();
        expect(players, isEmpty);
        speech.begin();
        delta('新轮。');
        expect(players.single.sentences, ['新轮。']);
      });
    },
  );
  test('partial image destination and alt text never reach speech', () {
    fakeAsync((time) {
      delta('开头 ![图片](https://private');
      time.elapse(const Duration(milliseconds: 800));
      expect(players.single.sentences, ['开头']);
      delta('.example)末尾');
      time.elapse(const Duration(milliseconds: 800));
      expect(players.single.sentences, ['开头', '末尾']);
    });
  });
  test('final TEXT_REPLY does not bypass incomplete Markdown filtering', () {
    speech.accept(
      const AgentEvent(
        AgentEventKind.finalResponse,
        text: '说明 ```内部代码',
        payload: {'type': 'TEXT_REPLY'},
      ),
    );
    expect(players.single.sentences, ['说明 ']);
  });
  test('plain exclamation still completes a sentence immediately', () {
    delta('Hello!');
    expect(players.single.sentences, ['Hello!']);
  });
  test('complete sentence starts a fresh wait for its unpunctuated tail', () {
    fakeAsync((time) {
      delta('前半');
      time.elapse(const Duration(milliseconds: 600));
      delta('句号。尾段');
      expect(players.single.sentences, ['前半句号。']);
      time.elapse(const Duration(milliseconds: 200));
      expect(players.single.sentences, ['前半句号。']);
      time.elapse(const Duration(milliseconds: 600));
      expect(players.single.sentences, ['前半句号。', '尾段']);
    });
  });
  test(
    'synthesizing suppresses idle flush, full sentences still queue',
    () => fakeAsync((time) {
      delta('第一句。');
      players.single.synthesizing = true;
      delta('半句');
      time.elapse(const Duration(seconds: 1));
      expect(players.single.sentences, ['第一句。']);
      delta('结束！尾部');
      speech.finish();
      expect(players.single.sentences, ['第一句。', '半句结束！', '尾部']);
    }),
  );
  test(
    'final preserves explicit signal and flush ordering, not guessed dedup',
    () {
      delta('余部');
      speech.accept(
        const AgentEvent(
          AgentEventKind.finalResponse,
          text: '完整文本',
          payload: {'type': 'TEXT_REPLY'},
        ),
      );
      expect(players.single.sentences, ['完整文本', '余部']);
    },
  );
  test(
    'interrupt cancels buffered timer and late reply until next turn',
    () => fakeAsync((time) {
      delta('未分句');
      speech.interrupt();
      time.elapse(const Duration(seconds: 1));
      delta('旧回复。');
      expect(players, isEmpty);
      speech.begin();
      delta('新回复。');
      expect(players.single.sentences, ['新回复。']);
    }),
  );
  test('suppressed call or old account never creates playback', () {
    allowed = false;
    delta('不可播。');
    speech.finish();
    expect(players, isEmpty);
  });
  test(
    'signal prompts and receipt isolation do not read historical messages',
    () {
      speech.accept(
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'questions': {'question': '问题'},
          },
          text: '问题',
        ),
      );
      speech.accept(
        const AgentEvent(
          AgentEventKind.finalResponse,
          payload: {'type': 'CALL_RESULT'},
          text: '结果',
        ),
      );
      expect(players.single.sentences, ['问题']);
    },
  );
}
