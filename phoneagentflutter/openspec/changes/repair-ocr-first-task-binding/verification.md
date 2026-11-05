# OCR 首次上传绑定修复验证

## 批准与来源

用户于 2026-10-29 明确按前轮方案实施，重点 OCR、所有 Skill、保留正常流程/记忆确认/通话门禁；独立回归后推送 test_v1.8.0_fix、测试签名包、不安装。本次无新禅道编号；诊断包 (9) 与视频在本机读取，不提交个人数据。Java 基线 1ea1d6791，Flutter 基线 d678e713。

## RED → GREEN

- OCR-only 恢复新增测试原先断言失败：期待原 Skill，实际 null。
- 标题新增 7 个回放原先 5 个失败：真实任务输入后仍为上传占位。
- 修复后 Java 首轮定向回归 288 项，0 failures/errors/skipped；补 SystemMessage 锚点后的最终定向回归 290 项，0 failures/errors/skipped。覆盖 OCR/绑定/所有注册 Skill、元数据-only 与账本冷恢复、初始预选、记忆使用确认/无候选/拒绝、批量确认、普通拨打确认、AgentService。
- Flutter 229 项通过，flutter analyze 无问题；覆盖 OCR、上传意图/提交字段一致性、退出恢复、附件与文字/文档、pending、单人批次/多人确认与恢复准入、列表标题。
- 新增账本冷恢复夹具第一次漏 source 字段，按真实客户端 CONTACT_DETAIL 来源补齐后通过，未改放宽原 codec 规则。

## 扩大回归

初次扩大后端回归 426 项，出现 AgentServiceToolLoopTest 4 项断言、3 项超时，以及上述新增夹具问题。夹具已修复；独立 agent 从 1ea1d679 导出隔离基线，7 个同名用例复现同样的 4 项断言与 3 项超时，确认改前已存在，未改原断言或顺手修复。

## 独立验收

未参与实现的独立 agent 重新读取诊断包 (9)、两张原始截图及原视频并重新抽帧，未发现本次新增交付阻塞。

- Java 399 项总计：388 通过、0 failures、0 errors、11 skipped。跳过项是 ConversationListProjectionIntegrationTest，未设置隔离 MySQL 参数，不计通过。包含 9 个独立挑战，覆盖上传授权尚未完成时的元数据-only 恢复、开场/OCR/USER 账本、重复/异账号/迟到上下文、原记忆与未知字段保留、绑定与已发布首页标题映射。
- Flutter 243 项通过；另 2 个 iOS 任务入口 Timer 用例在 d678e713 隔离基线上同样失败，Android 对应入口通过。独立临时测试的 const 夹具修正后 14 项最终挑战全过；不计作产品失败。
- 独立报告：本机 D:/Temp/ocr-independent-20261029/acceptance.md。当前生产与测试源码已逐文件匹配独立候选快照哈希。
- product AOT 检查通过：测试三路地址、Release 环境/HTTPS 拒绝规则、SDK 登录路由及签名来源；无网络请求。原身份 SDK 的 8 个 Android AAR 与 328 个 iOS 文件按登记历史提交核对一致。

## 证据边界

最终提交与测试包结果在交付记录补充。未部署、未安装、未执行真实外呼；旧异常会话未自动改写或重拨。缺隔离数据库并发实测、11 项数据库集成、部署后手机画面及实际通话证据；自动回归阶段通过不冒充这些实际运行结果。

## 收尾补充

上传授权后尚未 complete 的元数据-only 任务缺少系统消息锚点，AgentService 原 prepareMessages 只替换已存在的首条系统消息。新增读缓存前/后两项先 RED（2 failures/0 errors），只在该空消息且有 pin 的恢复分支补锚点，之后 290 项 GREEN；既有非空历史不变。

追加独立复验 365 项全部通过（0 failures/errors/skipped），覆盖真实 PromptLoader、SkillRegistry 与 AgentService.prepareMessages；11 个注册 Skill × 3 个直接/只读缓存/空白提示缓存路径共 33 组均保留完整基础系统提示与绑定 Skill 指引、用户正文、记忆与 pending 边界，非空历史顺序不变。原 11 项 MySQL 跳过不混入这次通过计数。

测试 APK 已从已推送的 Flutter 01ee69640c113ceb377eb51c399d43a2b4c61c60 构建；后续 Java 补充不改变客户端二进制。包名 com.vvtech.aiassistant.test，1.0.54(47)，ARM64 Release，登记证书 MD5 ebd4c931de412bf5d9c3716815389097；三类服务同属 chakenai-test.vvtech.tech。SHA256 483e1d96171fbbddbcc002ff43e59a9796158a62d2f07609577294ecfcd9a30f。

Release 引擎按标准 strip 后逐字节相同，AOT 存在、无 debuggable/kernel_blob/调试 Vulkan/签名私有输入；受控 AAR 中 12 个 JNI 与 8 个 assets 逐字节匹配。APK 文件见本机交付目录 deliveries/ocr-skill-test-20261029_145003/Phone_Agent_TEST_1.0.54_47_test_20261029_145003.apk，不安装。

独立 agent 对该实际 APK 重新读取 aapt/apksigner、计算同一 SHA256、逐字节比对 Release 引擎/AAR，并重新 product-AOT 编译执行配置与签名 SDK 路由检查，均通过。最终推送前保留同期远端 3b073f638 的 Netty/IndexTTS 改动，未改写其他任务；这些文件不改变本次 Agent SSE/Flutter 候选源码哈希。OpenSpec 保留未部署/未安装/实际外呼与数据库并发证据边界，不归档为真实环境完整验收。
