# 验证记录（2026-10-30）

## 授权、基线与范围

用户已批准工作区PDR v1，明确要求修复App、保护正常播报与确认拨号，回归后提交推送feature/test_v1.8.0，用户自行构建，生产配置不变。实施基线d8dcdffc；保留此前会话失效、邀请码登录修复及原检出三个未提交文件。

产品修改仅三个接线点，新增37行/替换1行：成功应用的首次实时事实回调，当前命令/record与确认卡及可见消息核对，原播报owner接收v1补充正文。不修改Java事件、语义分类、待确认状态或拨号动作，不创建新音频队列。

## 已完成

- 红：新增13项连续回放，修复前5项失败、8项保护边界通过；确认提示可入队，补充文字显示但不入队。
- 绿：13项全部通过；连同既有补充流程共15项通过。覆盖问题/等待/不明确反馈、同文不同命令、重复事件、原卡pending及零拨号动作、历史不重播、gap旧事实不播报、静音/后台/打断/关闭、命令/卡/会话/schema身份。
- 自验：播报与确认针对性472项全部通过；受影响四文件flutter analyze无问题、dart format零改动、UTF-8严格读回及git diff --check通过，OpenSpec strict通过。
- 扩大回归voice/calls/confirmation：804项通过、17项失败。下节明确基线对照，不将扩大检查称为全通过。
- 未参与实现的独立代理重新读取截图、PDR、规则、知识库及实际源码接线，独立重跑472项全部通过。
- 独立新增仓外14项探针全部通过：record不匹配、空user未投影、sequence/event冲突、done/业务错误/传输错误后迟到，异步补查期间close/restore/interrupt/background/mute失去资格，冲突REST副本和实时冲突重复。探针不修改产品或既有断言。
- 独立代理另在候选与基线各复跑相关失败文件：均51通过/17失败，failure keys差异0；在基线运行独立补充入队探针确为RED，在候选为GREEN。最终认可本次限定源码交付，未声称真机听音或完整发布验收。

## 未通过：基线已有的17项

在未修改的79ef9f3d检出复跑相同用例，失败名单与候选完全一致（17/17，无新增失败名）。该基线到d8dcdffc的lib/features/conversation、lib/features/calls及对应test目录diff为空，涉及源码/用例相同。没有删除测试、修改旧断言或把基线失败算通过。

| 文件 | 失败数与范围 |
| --- | --- |
| voice/points_rejection_narration_test.dart | 4：独立命令的相同积分拒绝播报 |
| calls/continuous_task_orchestration_test.dart | 3：历史确认提示/单多路连续编排 |
| calls/conversation_outcome_thinking_test.dart | 2：Android/iOS主题的物理结束与恢复 |
| calls/conversation_structured_failure_test.dart | 3：未登记观察与最终结果清理 |
| calls/task_160_call_test.dart | 1：preview与新attempt匹配 |
| restored_batch_confirmation_focus_test.dart | 4：Android/iOS主题的实时/恢复长确认卡定位 |

这些既有问题未扩入本次补充回复播报补丁，不承诺已修复。

## 缺证据与证据定位

未安装构建包、未操作生产配置、未执行真实电话或TTS供应商合成。播放端口为替身，证明文本进入原播放队列及门禁，不等于真机可听结果；用户构建更新后仍需设备实际听音验证。没有改变布局或弹窗。

本机证据：工作区.local-data/batch-confirmation-tts-20261030下red.log、green.log、focused-regression.log、regression.log、baseline-points.log、baseline-expanded.log、baseline-last.log、baseline-comparison.json、analyze.log；独立edge-probe.log与regression.log位于该目录independent下。

提交号以本变更所在Git提交及交付消息为准。实际交付仅Flutter App，不需要为本次部署后端。
