import '../domain/ocr_attachment.dart';

enum OcrPreviewScenario {
  contact,
  meeting,
  emptyText,
  recognition,
  refinement,
  cloudCommit,
}

class PreviewOcr implements OcrRecognizer, OcrCommitter {
  final Map<String, OcrPreviewScenario> scenarios = {};
  static const contactImage =
      'assets/images/conversation/mock-ocr-contact-card.png';
  static const meetingImage =
      'assets/images/conversation/mock-ocr-meeting-poster.png';
  static String asset(String ref) =>
      ref.startsWith('meeting:') ? meetingImage : contactImage;
  @override
  Future<OcrRecognition> recognize(String imageRef) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final scenario = scenarios[imageRef];
    if (scenario == OcrPreviewScenario.recognition) {
      throw StateError('synthetic recognition failure');
    }
    return OcrRecognition(
      scenario == OcrPreviewScenario.emptyText ? '' : '合成资料，仅演练',
      const ['合成资料'],
    );
  }

  @override
  Future<OcrContent> commit(
    OcrAttachment attachment,
    OcrRecognition recognition,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final scenario = scenarios[attachment.imageRef];
    if (scenario == OcrPreviewScenario.refinement) {
      throw const OcrCommitFailure(OcrFailure.refinement);
    }
    if (scenario == OcrPreviewScenario.cloudCommit) {
      throw const OcrCommitFailure(OcrFailure.cloudCommit);
    }
    if (scenario == OcrPreviewScenario.meeting) {
      return OcrContent(
        fullText:
            'Innovation Summit\n会议海报演练：本条内容用于验证长文字展开与收起，以及识别图片后继续输入。所有信息只保存在当前演练页面，不会创建真实会议、上传图片或向任何号码拨打电话。',
        fields: const [
          OcrField('活动', 'Innovation Summit'),
          OcrField('时间', '7 月 18 日 14:00'),
        ],
      );
    }
    return OcrContent(
      fullText: 'Jack Wong\nVVTech\n合成名片仅用于交互演练',
      fields: const [OcrField('人名', 'Jack Wong'), OcrField('机构名称', 'VVTech')],
    );
  }
}
