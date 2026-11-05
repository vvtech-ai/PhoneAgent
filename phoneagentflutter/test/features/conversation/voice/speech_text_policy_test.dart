import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/voice/speech_text_policy.dart';
import 'package:phone_agent/features/conversation/domain/voice/speech_prompt_policy.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

void main() {
  test('v65 first full delimiter takes precedence; comma only above 80', () {
    expect(SpeechTextPolicy.sentenceEnd('一，二。三!'), 3);
    expect(SpeechTextPolicy.sentenceEnd('${'甲' * 78}，乙'), -1);
    expect(SpeechTextPolicy.sentenceEnd('${'甲' * 79}，乙'), 79);
    expect(SpeechTextPolicy.sentenceEnd('hello\nworld'), 5);
    expect(SpeechTextPolicy.speaker, 'Maia');
  });
  test('v65 markdown stripping removes decoration, not identifiers', () {
    expect(
      SpeechTextPolicy.clean(
        '# 标题\n**重点** [链接](https://invalid) `代码`\n- 项目\n1. 顺序\n![图片](x)\n```hidden```',
      ),
      '标题\n重点 链接 代码\n项目\n顺序',
    );
    expect(
      SpeechTextPolicy.clean('a_b_c *斜体* ~~删除~~ ***加粗***'),
      'a_b_c 斜体 删除 加粗',
    );
    expect(SpeechTextPolicy.clean('```only code```'), '');
  });
  test('unfinished emphasis does not expose markup in early speech', () {
    expect(SpeechTextPolicy.cleanStreamingSegment('**重要内容'), '重要内容');
    expect(SpeechTextPolicy.cleanStreamingSegment('~~稍后'), '稍后');
    expect(SpeechTextPolicy.cleanStreamingSegment('3*4'), '3*4');
    expect(SpeechTextPolicy.cleanStreamingSegment('请拨打 *123#'), '请拨打 *123#');
  });
  test('literal service codes remain unchanged in final-result cleaning', () {
    expect(SpeechTextPolicy.clean('请拨打 *123#'), '请拨打 *123#');
  });
  String prompt(
    String type, {
    String text = '',
    Map<String, Object?> extra = const {},
  }) => SpeechPromptPolicy.prompt(
    AgentEvent(
      AgentEventKind.signal,
      text: text,
      payload: {'type': type, ...extra},
    ),
  );
  test('ask uses one prompt or title and multiple prompts', () {
    expect(prompt('ASK_USER'), '');
    expect(
      prompt(
        'ASK_USER',
        extra: {
          'questions': {'title': '再确认几件事', 'items': []},
        },
      ),
      '',
    );
    expect(
      prompt(
        'ASK_USER',
        text: '内部跳过，继续执行',
        extra: {
          'questions': {'items': []},
        },
      ),
      '',
    );
    expect(
      prompt(
        'ASK_USER',
        extra: {
          'questions': {
            'title': '细节',
            'items': [
              {'prompt': '几点？'},
            ],
          },
        },
      ),
      '几点？',
    );
    expect(
      prompt(
        'ASK_USER',
        extra: {
          'questions': {
            'title': '细节',
            'items': [
              {'prompt': '时间'},
              {'prompt': '地点'},
            ],
          },
        },
      ),
      '细节：时间，地点',
    );
  });
  test(
    'call confirmation speaks the exact native question, not task facts',
    () {
      expect(
        prompt('MAKE_CALL_REQUEST', text: '旧摘要，含合成号码'),
        '请确认以上任务内容，是否现在拨打？',
      );
    },
  );

  test('legacy ASK_USER question is spoken instead of title only', () {
    expect(
      prompt(
        'ASK_USER',
        extra: {
          'questions': const {'title': '补充会议', 'question': '请提供会议时间和地点'},
        },
      ),
      '请提供会议时间和地点',
    );
  });
  test('ASK_USER arguments are spoken when the root has no items', () {
    expect(
      prompt(
        'ASK_USER',
        text: '需要你补充信息',
        extra: {
          'arguments': {
            'title': '补充联系人信息',
            'items': [
              {'prompt': '联系人姓名？'},
            ],
          },
        },
      ),
      '联系人姓名？',
    );
  });
  test('options narrate place ordinal and contact phone', () {
    expect(
      prompt(
        'SHOW_OPTIONS',
        extra: {
          'options': {
            'title': '找到',
            'items': [
              {'label': '店一', 'address': '路'},
              {'label': '店二'},
            ],
          },
        },
      ),
      '找到。第一家，店一。第二家，店二',
    );
    expect(
      prompt(
        'SHOW_OPTIONS',
        extra: {
          'options': {
            'items': [
              {
                'label': '小王',
                'phone': '+10000000000',
                'tags': ['CONTACT'],
              },
            ],
          },
        },
      ),
      '请选择。第一个，小王，+10000000000',
    );
  });
  test('final TEXT_REPLY only; receipts do not become synthetic narration', () {
    expect(prompt('TEXT_REPLY', text: '回复'), '');
    expect(
      SpeechPromptPolicy.prompt(
        const AgentEvent(
          AgentEventKind.finalResponse,
          text: '回复',
          payload: {'type': 'TEXT_REPLY'},
        ),
      ),
      '回复',
    );
    expect(prompt('CALL_RESULT', text: '结果'), '');
    expect(prompt('REQUEST_PERMISSION'), '需要你授权后才能继续');
    expect(prompt('IMPORT_DOCUMENT_REQUEST'), '请上传 Markdown 或 TXT 文档');
  });
}
