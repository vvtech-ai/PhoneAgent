# 2026-10-19 声音克隆流程及结果归属验证

## 基线与改动

Flutter `codex/dev@0a26665d`，Java `feature/test_v1.7.0@0c1e9d55`，只读对照原生 `feature/test_v1.6.0@8f23592` 的 `VoiceCloneEnrollmentReducer.resetVerificationWithError`。没有拉取或修改旧工作区。

共享Flutter工作树在15:23:59由其他会话快进至 `f7452e37`（既有iOS邀请/构建配置提交）；本次没有执行pull，最终542项及analyze在快进后的源码上完成。远端又有后续提交，本轮不覆盖或强推共享分支。

用户随后授权检查、提交推送：安全保存本批后快进到 `origin/codex/dev@44a16ebd`，恢复修复并保留两边任务文档；源代码无冲突。提交前增加配置/登录接线复验，564项通过、analyze无问题、OpenSpec200项通过。Java在原正确分支重新执行110项（含独立MySQL）通过；两个仓库均只提交本次修复，运行态待验项保留。

- 认证拒绝、跟读失败、取消、明确克隆失败在填写身份页提示；保留当前页面的身份与授权，姓名和证件脱敏。退出或主动身份重置仍清除，不持久化完整证件。
- 同步后才确认失败也能主动重新认证：旧候选在新提交前释放，不再挡住新的认证回调。
- 原提交结果未知时，最新候选 GET 不证明它属于本次提交；保留同步，禁止自动确认、试听、重新生成或显示本次扣费。
- iOS 试听在现有媒体租约下先调用独立平台适配器，显式设置 playback/default/mixWithOthers 并激活；前后台/系统通话/认证占用不强抢。优先级错误最多两次短等待，取消后不启动播放器。
- Java 同名 change 新增训练证据：提交前保存 candidate/model/speaker 和训练版本；只有本次版本推进且 READY 才允许结算。试听、确认和目录读保护已知跨账号槽位历史的旧异常记录。

候选展示规则放在现有独立 presentation 模块，平台会话在独立 data/Objective-C 文件；主控制器只增加失败资源释放接线，保持 500 行。音质门槛、价格、每日次数和成功冷却规则未调整。

## 验证

- 新增失败恢复、同步后失败重试和未知结果禁用操作用例，修改前按预期失败，修复后通过。
- Flutter 3.32.0：`flutter test --no-pub test/features/voice_clone test/architecture_test.dart`，542 项通过；`flutter analyze --no-pub` 无问题。
- Dart 播放前置会话、准备期间取消、错误后可重试已覆盖；不替代 Objective-C 编译或 iOS 真机验证。
- Java SDK/SSE 定向110项通过，含训练版本、旧READY、防串音试听/确认、旧激活、默认/显式通话、对账、供应商适配及目录回归。独立复核发现的库存语义与实际通话绕过已补齐，二次复核未发现新的重要缺陷。
- 新迁移脚本和SDK/SSE两套实际MyBatis Mapper在独立MySQL5.7测试库验证，覆盖重复迁移、record映射、版本原子核对、账号/模型隔离及逻辑删除历史；测试库已删除。未修改dev/test业务库。
- Flutter OpenSpec 全仓 199 项通过。Java 同名 change 严格校验通过；全仓 89/90 通过，既有 `audit-v66-single-call-stop-ui-parity` 在 HEAD 已缺 delta，本次未修改。
- PMReport 注册清单仅有旧 `aiassistant`，实际 `phoneagentflutter` 和 `aiassistant-java` 独立仓库未登记，不冒用旧仓库上报。

## 仍待验收

1. 在业务库先执行 Java `sql/migrations/V202610190001__create_voice_clone_training_proof.sql`，再发布SDK和SSE；本轮未执行业务迁移、部署、退款或重绑。
2. 用实际供应商响应验证当前 legacy status 接口的 `version` 是否可按训练版本核对。缺失、回退、不透明版本保留未知或拒绝提交，不以历史 READY 降级成功。本机规定的主密钥文件缺失，未尝试使用其他密钥或读取明文供应商凭据。
3. 在 Xcode 编译并用 iPhone 验证跟读后完成页、返回列表试听、取消/后台/系统通话；Windows 未完成这些验收。
4. 已异常确认的远端音色不会因代码修改自动变成本人声音；保护会阻止已识别的异常记录，后续需重新克隆。既有扣费是否退款需单独核对处理。

未打包或安装本批源码，未发起真实人脸认证、供应商训练或收费试听。
