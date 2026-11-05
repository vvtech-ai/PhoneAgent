# 2026-10-19 验证记录

## 基线与范围
Flutter codex/dev 5b91fb7d，Java feature/test_v1.7.0 6fa8763e；分别fetch及ff-only同步，起始工作区干净。只实现本change五项用户确认需求，不修改原生参考工程、Web、私有配置、版本或构建入口。

## 已执行
- Java JDK17：mvn -q -pl aiassistant-sdk-api -am -Dtest=VoiceCloneMfvcAdmissionServiceTest,VoiceCloneVerificationQuotaTest,VoiceCloneEnrollmentOutcomeReaderTest,VoiceCloneVerificationPhoneIdentityTest -Dsurefire.failIfNoSpecifiedTests=false test，37项通过。原计数回归先复现未完成占次数失败，再修复通过。
- Flutter定向：conversation_input_feedback、restored_batch_confirmation_focus、tts_composer_control、v66_conversation_composer、v66_text_input_stability、native_conversation_system_keyboard、conversation_thinking_ui；membership_queue/page/partial_page；domestic_translation_session_controller/factory、domestic_points_owner、translation_session_pages/controller；clone_verification_admission；architecture_test。最终联合命令success=true。
- flutter analyze 无问题。首次测试漏导入、一次命令误用test/architecture目录已纠正；最终使用实际test/architecture_test.dart成功。
- Flutter openspec validate --all：202/202；Java本次change strict通过，全仓90/91，历史audit-v66-single-call-stop-ui-parity缺spec delta，不改无关文件。
- 本次文本UTF-8、中文与git diff检查。PMReport registry未登记phoneagentflutter及aiassistant-java，不执行上报。

## 行为与边界
认证上限来自GlobalConfigKey.VOICE_CLONE_MFVC_DAILY_LIMIT，账号及同一身份跨账号都检查。以服务端PASS/FAIL写入的completedAt统计完成日；包含旧记录完成后被EXPIRED覆盖但仍有完成事实的情况，不删除历史记录、不清空计数。认证结果重复查询保持终态，克隆材料自身过期准入仍保留。

Toast只使用国内实际结算金额；没有完成结算不估算扣分。套餐列表排序和购买规则不变。UI与Toast测试为widget模拟，不代表实机/供应商验收。

## 待验
Java SDK部署、新Flutter包、真实国内通话结算、阿里云认证及Android/iOS界面联调。未操作业务数据库，未真实认证/外呼，未打包安装。版本保持用户指定1.0.52 (45)。
