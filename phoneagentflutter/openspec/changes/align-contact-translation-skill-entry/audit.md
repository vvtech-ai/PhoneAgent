# 首页 Skill 及联系人首轮行为核对

审计基线：Native `aiassistant-app` `feature/test_v1.6.0` `8f23592`；Flutter `codex/dev` `340bf658`，含本轮合入 `dev_zys` 的代码。仅源码和既有测试核对，不代表真实服务或外呼验收。Native 路径以下省略 `app/src/main/java/com/vvtech/aiassistant/`；Flutter 路径相对仓库根目录。

## 实证差异与处理

| 严重度/结论 | Native 证据 | Flutter 证据 | 测试与最小处理 |
| --- | --- | --- | --- |
| P2，已实施待绿测：联系人遗漏实时翻译 | `features/assistant_contacts/AssistantContactSkillPolicy.kt:20-33` 保留 OpenTranslation，标题实时翻译；`AssistantContactSkillSheet.kt:72-82` 分派翻译；`features/assistant/AssistantContactPageHostArgs.kt:61-63` 传当前姓名号码 | 原 `lib/features/contacts/presentation/controller/contact_skills_controller.dart:31-35` 仅enabled OpenSkill；原 `presentation/pages/contact_actions.dart:79` 一律创建任务 | 新 `test/features/contacts/contact_translation_skill_entry_test.dart` 实跑红测 +1/-4，disabled隐藏通过；最小补目录与复用openDialer预填、translationEntry=true，不自动外呼 |
| 已批准差异，保留：网络失败回退 | `data/homeconfig/HomeConfigRepository.kt:36-38` 用缓存，无缓存走 `HomeConfigDefaults.kt:8-12` 空目录 | `lib/features/home/data/dio_home_repository.dart:94-96,112-114` 回退builtin | `MIGRATION_BASELINE.md:27` 与 `refactor-conversation-task-flow/specs/home-conversation-entry/spec.md:82` 明确保留v66内置回退；`home_repository_test.dart` 明确验证失败用builtin，不改 |
| 已批准差异，保留：联系人会议/活动无模板开场 | `AssistantContactSkillOpeningPolicy.kt:20-30` 仅订餐内置个性化，其余用已发布opening | `lib/features/contacts/domain/contact_skill_opening.dart:14-18` 保留会议/活动v66开场 | 当前 `home-conversation-entry/spec.md:11,20` 明确要求保留；`contact_skill_opening_parity_test.dart:34-61` 覆盖，不改 |
| 目录展示差异，未判缺陷：首页偏好与联系人目录 | `HomeConfigViewModel.kt:88-90` 先应用账号首页偏好，只传可见卡到联系人 | 联系人controller独立读取完整公共目录，不套首页隐藏/排序偏好 | 本次只补缺失翻译入口，保留Flutter联系人独立可用目录；未找到用户要求隐藏首页卡同时隐藏联系人能力的证据，不扩大改动 |

Native 的 Disabled 卡先被 `HomeCardPreferencePolicy.kt:17` 排除，再传到联系人选择策略，因此翻译例外仅覆盖 comingSoon 或版本不足，Disabled 仍隐藏。

## 已对齐与责任边界

| 能力 | Native 证据 | Flutter 证据/已有验证 | 结论 |
| --- | --- | --- | --- |
| 订餐、会议邀请、活动邀约、销售推荐、大型会议邀请、道歉目录 | `HomeConfigMapper.kt:21-31,85-92` 从发布目录和skillRefs读取，并不本地定义业务流程 | `lib/features/home/data/home_config_mapper.dart:16-26,47-66` 同样动态读取；`home_repository_test.dart` 覆盖映射和版本门禁 | 已对齐；Java sdk-api `homeconfig/domain/HomeConfigDefaults.java:17-40` 与Flutter `home_defaults.dart:11-72` 的8卡默认ID/状态一致，道歉comingSoon不是客户端遗漏 |
| 卡片可用状态及最低版本 | `HomeConfigViewModel.kt:92-100` enabled、版本支持、非None才允许进 | `home_config.dart:56-59`、`home_page.dart:201` 及 `shell_task_navigation.dart:95` 双重检查 | 已对齐；`home_repository_test.dart`、`contact_skills_controller_test.dart` 有状态和实际版本回归 |
| 点击卡片进入统一会话，等待有效用户输入 | `HomeCardEntryDispatcher.kt:56-60` arm后仅进入语音页；`AssistantRootContactSkillEntry.kt:10-15` initialCommand=null | `shell_task_navigation.dart:103-112` 只创建ConversationEntry；`contact_actions.dart`普通Skill仍只导航 | 已对齐，不在客户端新建各Skill表单或自动外呼 |
| 发布开场与联系人模板 | `HomeConfigMapper.kt:88-92`；`AssistantContactSkillOpeningPolicy.kt:5-13` 替换contactName | `home_config_mapper.dart:19-26,65-66`；`contact_skill_opening.dart:8-12` | 已对齐；`contact_skill_opening_parity_test.dart:7-32` 覆盖模板优先级 |
| 首轮携带Skill、开场及隐藏联系人 | `AgentStreamTurnRunner.kt:157-160`；`AgentStreamTurnUseCase.kt:51-58` | `conversation_submission.dart:28-33`；`agent_protocol.dart:74-77,92-97` | 已对齐；`skill_task_orchestration_parity_test.dart:10-58` 覆盖订餐/会议/活动首轮、后续和恢复；销售/大型会议复用同一通用实现，未单独跑真实场景 |
| 联系人只消费一次、历史恢复不重新注入 | `PendingSelectedContactTurnContext.kt:12-15` take即清空；`AgentInitialSkillLaunchStore.kt:103-119` 绑定session消费 | `conversation_submission_flow.dart:130-134`；`conversation_controller.dart:320` restore标记initialSent | 同上既有回归覆盖；新账号和页面晚到保护见 `contact_skill_return_guard_test.dart` |
| 订餐记忆询问状态 | `features/assistant/viewmodel/AssistantUserContextHolder.kt:104` 每轮附restaurantContactMemoryAsked | `domain/context/restaurant_contact_memory_offer.dart:36`；`lib/app/agent_context_providers.dart:41-42` | 已有独立实现及 `restaurant_contact_memory_offer_test.dart`；联系人保存、复用、无需预订判断按批准基线由服务端权威处理 |
| 翻译/generic的固定skillId约束 | Native动作mapper不额外检查，但服务器发布校验固定ID | Flutter `home_config_mapper.dart:48-52` 要求固定ID | Java web-api `HomeConfigValidator.java:195-199` 明确固定translation/generic ID，Flutter约束符合服务端契约，不报缺陷 |

Skill业务资料收集、文档模板、会议/活动/销售的批量工作流、订餐选店及联系人记忆、任务状态权威由 Agent/SDK 服务负责；App负责发布目录呈现、入口前置、当前会话和首轮上下文传输、工具事实展示。不得依据Skill文档直接在App复制第二套状态机。道歉音色授权、模型切换和callVoiceSelection由主线程另行实现，本审计不重复修改。

## 本轮验证范围

- 已执行：读取仓库规范/知识库导航/迁移基线与相关现行delta；OpenSpec status/instructions；`git diff --check`。
- 主线程已执行新联系人翻译测试红测：+1/-4，目录和导航缺失，Disabled隐藏通过。
- 待主线程串行执行绿测、analyze及OpenSpec校验；本子任务未运行Flutter测试，避免重写构建插件注册器。
- 未进行真实联系人/电话/媒体操作、后端部署或Native修改。
