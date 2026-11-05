## Context

见 [proposal.md](proposal.md) 和 [通话记录隐私规格](specs/call-transcript-privacy/spec.md)。当前 `CallDialogue.parse` 从原始 `transcript` 解析说话人和正文；`CallReceipt.hasRecordedDialogue` 等领域判断复用解析结果，不能在解析时改写原文。`CallReceiptCard`／`ReceiptTranscript` 与 `BatchReceiptItemCard`／`NativeBatchTranscript` 分别渲染单路和批量记录，`SelectableText` 的 `semanticsLabel` 目前直接使用原文。`CallReceiptText` 还生成纯文本回执。`conversationReceiptValues` 和 `conversationSingleReceiptValues` 保存原值作为本地重绘比较输入，并非向用户输出文字。

本需求只改变通话记录的呈现。三段 FireRed 录音中的报号声音是否正确，仍由 Java 仓库的 `repair-firered-conversation-quality` 与 FireRed S2S 原始音频核对；隐藏界面号码不能作为声音修复的证据。

## Goals / Non-Goals

**Goals:**

- 同一手机号在单路、批量、实时、历史、纯文本、复制和无障碍入口得到相同的脱敏展示。
- 对可可靠还原的号码只显示最后四位；对明显是号码而尾号不可靠的片段整体隐藏，不残留前段数字。
- 保留通话记录对象及所有业务执行路径所需的原始号码、对话身份与顺序。

**Non-Goals:**

- 改写服务端字幕、账本、模型指令、拨号目标或录音音频。
- 修改“已打断…”提示或通话声音质量；不引入新的打断判断。
- 将本次展示规则扩展到联系人编辑、任务确认等非通话记录页面。

## Decisions

### 1. 在呈现边界共用一个纯文本转换

在 `lib/features/conversation/presentation/widgets` 的通话回执展示层提供一个不带副作用的号码脱敏函数。`CallDialogue.parse`、`CallReceipt`、`BatchReceiptItem` 和服务端数据保持原值。单路／批量卡片、结果摘要及字段、`CallReceiptText` 只在绑定 `Text`／`SelectableText`、复制字符串与 `semanticsLabel` 时调用同一函数。`conversation*ReceiptValues` 作为原始输入变化检测保留现状；若将来其返回值被直接输出，再走展示转换。不能在通用 `ReceiptFieldRow` 内无条件修改所有业务字段，而应由通话记录调用处传入显示值。

### 2. 有界识别与无法确认时隐藏

识别完整的大陆手机号：连续或带常见空格／停顿的 11 位数字，首位为 1、第二位为 3～9；对“幺／一／壹”等单数字中文读法按位置映射后再校验，允许混用中文数字与阿拉伯数字。只对匹配的完整号码片段替换为“尾号 XXXX”，保留周围语句。对处在“电话／手机号／号码”等语境中、长度接近完整手机号但含“百”等歧义字的疑似报号片段，整体替换为“电话号码已隐藏”；不得拿最终四个可见字符臆造尾号。短数字、日期、价格和人数不被误认成手机号。检测范围与停止边界应明确，避免把紧邻的普通对话吞掉。

可以通过返回独立展示字符串实现；不把正则匹配结果写回模型或持久对象。考虑到语音识别可能产生“幺幺八百…”等异常表达，回放用例必须覆盖成功还原、歧义隐藏、相邻普通数字和一句话中多个号码。

### 3. 用户可取到的文本与画面同源

`SelectableText` 的正文和 `semanticsLabel` 使用同一个已脱敏值；纯文本回执的号码字段、转写与其他可能含手机号的结果文字走相同函数。单路、批量卡片共用转换逻辑，不分别维护两套规则。实时更新和历史恢复只重新计算展示值，不改回执身份、扩展状态或账本顺序。

## Risks / Trade-offs

- [中文报号识别不稳定] → 只在数位可确定且符合完整手机号时给出尾号；明显是电话号码但尾号不明时整段隐藏，回放验证无残留。
- [误遮普通业务数字] → 用号码长度、前缀、语境和词边界约束；用短号、时间、金额、人数做反例。
- [某个入口漏用转换] → 列出单路／批量卡片、展开转写、纯文本、选择复制与语义标签的直接调用点，使用组件回放检查一致性。
- [其他模型记录显示变化] → 这是通话记录展示层的统一隐私规则；业务对象和媒体链路不变，单独核对非 FireRed 样本。

## Migration Plan

不迁移历史数据。上线后实时和历史通话记录在渲染时采用新规则；回退客户端版本即可恢复旧展示行为，既有原始回执不需转换或重写。仅在后续实施阶段进行定向纯函数及组件验证，真实设备画面需按提测流程另验。
