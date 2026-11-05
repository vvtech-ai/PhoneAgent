# 本地验证（2026-10-30）

## 源码与接口

Flutter `feature/test_v1.8.0`，起始26ce44a0，验证时HEAD da9242ae；SDK同分支，HEAD 1a1bf12ef。未修改Swift、插件、锁文件、数据库或部署配置。每个手写逻辑微批最多3文件，文档与机械格式化单独进行。

SDK微批：增量Controller/Service/DTO；认证principal/过滤器/材料准入；材料事务/operations/原Controller；环境兼容gateway与各组测试。客户端微批：纯业务端口/C1网络/加密队列；独立协调器/providers/安全反馈文案；原runtime/providers/App接线；verifier/预检/恢复结果；状态/共享反馈；只刷新会员的catalog接线；各组回放及deadline/发现资格收尾。

## 已执行

- 固定Flutter 3.32.0/Dart 3.8.0。支付模块第一轮完整修正后976项通过；增加恢复报告/权益刷新回放后，与注销、登录widget、AccountApi、C1Transport联合1114项全部通过。末次发现权限与并发处理中去重补充回放另16项通过（与联合集合有重叠，不相加作为总数）。
- `flutter analyze --no-pub lib/features/commerce lib/app/commerce_providers.dart lib/app/apple_transaction_providers.dart lib/app/phone_agent_app.dart test/features/commerce`：无问题。
- 显式JAVA_HOME为本机JDK17，Maven `-pl aiassistant-sdk-api,aiassistant-agent-sse -am`；定向SDK commerce/accountauth/accountcancellation、C1SdkRequestFilter与SystemVoicePreview：95套件，480项，424通过、56条件跳过，零失败/错误；模块及直接依赖编译通过。
- 两仓本change OpenSpec `validate --strict` 通过；UTF-8、相对链接和git diff空白检查通过。默认PATH缺Node，改用已有本机Node和已缓存OpenSpec，未安装/升级依赖。

覆盖 APPLE-LIFE-01～08：账号/未登录作用域持有、真实runtime退出后的迟到结果、同SKU跨账号预检、原生旧交易返回后的新单结束、处理中/失败不finish、完成幂等finish、重启清理、存储/finish失败保留、有限重试、恢复失败与空发现区分、当前会员选择保留、v1/v2 epoch、伪造epoch忽略、普通接口所有权保留、C1必须、Android原单重试与原回调回归。DEVICE-01/ENTRY-03的相邻账号隔离由相关控制器和provider回放覆盖；未变更任务历史合同。

## 外部验收与发布顺序

本次没有连接真实后端/数据库写入，没有请求真实短信/支付、构建IPA/APK或安装设备。数据库并发、真实退款/回调、Sandbox与旧安装包均待环境授权及验收。

先发布含受限补单端点与材料门禁的SDK服务，再发布新iOS客户端。客户端请求新端点失败时保留证据并停止finish，不能用本地成功冒充服务端完成；不要将新客户端先于对应SDK能力发布。无需本次DDL。

Apple原始合同：[购买权限与已有交易](https://developer.apple.com/documentation/storekit/appstore/canmakepayments)、[unfinished](https://developer.apple.com/documentation/storekit/transaction/unfinished)、[finish](https://developer.apple.com/documentation/storekit/finishing-a-transaction)。既有交易发现不等于新购买授权；付款与权益处理完成后再finish。
