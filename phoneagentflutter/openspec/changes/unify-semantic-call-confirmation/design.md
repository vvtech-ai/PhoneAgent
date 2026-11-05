# 设计

获批 PDR：工作区 docs/semantic-call-confirmation-PDR.md。基线 f285726b，Java 配套基线 d28c704f。

ConversationConfirmationFlow 只协调当前可见卡与语义答复；分类交给原 CallConfirmationReplyCoordinator，后者按 scope 和 revision 丢弃旧结果。API 返回结构不变，后端自行读取权威卡片。明确同意仍调用原 ConversationCallController.confirm，既有 1500ms 准备与准入保持。

新的自然输入会先暂停尚未提交的拨号准备，避免等待分类期间开始执行；同一准备操作的相同答复按身份抑制重复，不用文本来授权。QUESTION/WAIT/UNCLEAR 使用已有 supplement 并继续等待，EDIT/CANCEL/NEW_REQUEST 回原 Agent 链。缺分类能力或异常不执行；明确按钮直接调用原 confirm。

不新增第二套呼叫状态机，不修改计费、停止、TTS 或页面布局。测试替身显式注入，仅代替外部语义服务。
