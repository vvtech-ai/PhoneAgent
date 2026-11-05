# 验证记录

用户2026-10-29批准实施及独立回归后推送test_v1.8.0_fix，客户端变更打1.0.54+47测试签名包，不安装。实现期间未部署、未外呼、未改业务数据。

## 已完成
- 公共batch_plus单呼逃逸拦截、重拨源/当前选择/执行规格绑定；无Skill名单。原首次单/多路、记忆授权及执行权益owner保持。
- 从账号所属已提交终态batchCallResult读取原来源；连续重拨沿sourceSnapshotId/retrySource追溯，保留新batch/attempt。最近已完成边界裁剪旧请求；补问仅传核对后的问题类型，不传记忆候选正文，不授予授权。
- 当前卡完整语义判断、仅异常一次重试、有效UNCLEAR不重试、可用性区分、同请求有界复用及旧卡前后核验。
- Java自验：clean影响面554项，0失败0错误，11项MySQL环境跳过；最终补问上下文修改后相关50项0失败0错误。日志D:/Temp/retry-java-clean-regression.log、retry-java-question-context.log。
- Flutter自验：相关33项及后续37项通过；最终analyze无问题。两组为不同集合，不能简单相加为唯一测试数。
- 未参与实现的独立agent：Java专项35项通过；最新真实账本/身份/执行/隐私17条集成挑战通过；Flutter专项58项通过，相邻32项通过。真实配置模型只读分类复验覆盖确认、当前换人、记忆问题插入、新任务及不明确。报告D:/Temp/batch-retry-independent-20261029/acceptance.md。
- 独立首轮发现的执行目标漂移、真实结果来源不符、历史目标累加及缺少记忆提问上下文均已修复并独立复验；未删旧断言迎合实现。

## 未通过与既有基线
- Flutter全量执行至7444通过、2跳过、155失败后，在旧workbench/route清理尾部停滞并有界停止，不能称全量通过。155条失败均已按文件+测试名在原基线211159d9复现；独立agent核对差集为0。
- Flutter相邻restaurant_memory_route_test的iOS付款timer失败在原基线独立复现，本次未修复无关逻辑。
- Java全量停在既有AgentServiceToolLoopTest.emptyRouteOutcomeStreamReturnsExecutionErrorAndReleasesBatchOccupancy等待，已保留线程证据并停止；不声称完整全量通过。期间两次并发Maven产生的无效结果不用于结论，随后单一clean重建回归通过。

## 缺证据
- 11项隔离MySQL测试未执行；无候选包安装、实际后端部署、真机连续外呼/音频及iOS原生验证。自动化与只读模型分类不等于真实拨号通过。
- 本文件不包含私有配置、凭据或原始用户诊断正文。

## 交付产物

- 功能提交：Java `fb320691db479a39d3ce2667b8caab62cb6ee00b`；Flutter `85e77d93d2a8e2ec798b9b0be46b13ca24de2d33`，已推送两仓`test_v1.8.0_fix`。Java快进保留其他开发者远端`17b0227ed`的Netty手机号播报修复，本轮未覆盖该差异。
- 测试签名包：`D:/work/04phoneAgent/_isolated/semantic-call-confirm-flutter/deliveries/batch-retry-test-20261029_165456/Phone_Agent_TEST_1.0.54_47_test_20261029_165456.apk`。
- SHA256：`d22dd660e748dedd854329df7f81939f8b09bda0a83f27cccfa8f2e413152ea7`。来源为上述Flutter功能提交；版本`1.0.54+47`、包名`com.vvtech.aiassistant.test`、Release/ARM64/AOT、登记证书签名有效。
- Agent/SDK/Runtime分别为`https://chakenai-test.vvtech.tech/aiassistant-api/`、`/aiassistant-sdk-api/`、`/aiassistant-runtime/`，均同一test环境。成包校验无私有签名/defines文件泄漏，12个JNI库与8个资产同受控AAR一致，Release引擎比对通过。
- 打包未安装，后端未部署。产物只读验证记录在`D:/Temp/phoneagent-batch-retry-build-20261029`，独立成包复核见外部验收报告。随后提交仅更新交付文档，不改变已验收功能源码或APK来源身份。
