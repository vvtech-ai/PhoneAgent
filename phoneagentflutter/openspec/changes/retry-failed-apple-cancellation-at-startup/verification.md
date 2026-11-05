# 验证与问题记录：最小取消补报

## 范围与证据
- PhoneAgent，codex/dev，起点5132667bfa20241a3e9a3086df2973662b7b98e7。开始时存在另一任务的iOS/APNs修改；未覆盖、回退或纳入本需求。
- 用户批准撤回统一调度/轮询/网络监听改造，仅处理StoreKit明确取消后上报失败的持久补偿。
- 原日志脱敏原单74d97aef56a5f07e在2026-10-21 15:56:25取消后HTTP statusCode=0，15:56:54仍PROCESSING；只确认客户端机制，不声明Apple扣款或服务器通知根因。
- RED：旧helper取消请求失败后，新控制器restore不补报，预期两次close实际一次；实施后同一控制器实际购买取消失败→持久待办→新登录启动使用原ID补报通过。

## 职责与接口
- domain/apple_cancellation_outbox.dart：唯一失败待办、稳定ID、同登录启动once标记；没有timer、事件订阅或订单状态投影。
- data/secure_apple_cancellation_store.dart：AppLocalStorage和PreferenceOperationQueue，按环境/API/账号隔离，保存原单及请求ID、同单不追加、同登录写入前后校验。
- 原apple_purchase_cancellation helper只为APPLE_IAP明确canceled调用outbox；PurchaseController只增加可选参数和一次传参（497行）。手动closeOrder完全不变。
- apple_cancellation_outbox_provider按loginEpoch持有；commerce_providers保留原启动restore立即执行，在其结束后补报一次。每原单先GET，终态直接清记录，否则至多一次close；失败留待下次启动。补报不占控制器busy，不阻塞原恢复。
- 若当前仍显示同一原单且未忙碌/报价/确认恢复，则复用原query更新结果；不添加轮询或监听。

## 保留与验证
- 原交易订阅/验单finish、结果route、反馈弹层、会员route、网络事件源/provider、TTS连接owner、Swift支付/网络通道共10文件与HEAD字节一致。
- 后端、平台、依赖、用户可见文案及UI均无本需求修改。保留支付成功优先、终态清理、账号隔离；取消只结束本地购买流程，不宣称Apple退款。
- 21项首轮支付及相邻验单/finish定向回归通过；13项启动provider/存储/补报回归通过。
- 覆盖：失败保存、同单唯一/原ID、重复启动/控制器重建不重复、手动失败不留待办、成功/取消/关闭清理、未知保留、旧账号迟到、持久存储失效不覆盖原错误、响应身份不匹配拒绝、原单查询期间账号切换。
- 规则与文档已更新；DEVICE-01仅自动化平台入口边界。真实iPhone杀进程断网回放、服务器回调/到账/finish仍待验，不归档。

## 未执行项
未构建安装、未执行真实支付/退款、未修改后端和线上订单、未提交推送。存储插件测试使用mock，不能代表真机沙盒写入成功。

## 最终检查
- 商城模块和音色克隆直接调用页面699项测试通过，日志.local/apple-cancel-startup-minimal-tests.log；不是全仓测试。
- Flutter3.32.0 / Dart3.8.0：flutter analyze --no-pub无问题。
- 当前OpenSpec change strict、UTF-8读回、文档链接及git diff --check通过。
- 本次业务源码仅3个既有文件的小幅接线与3个新文件（domain outbox、secure store、账号provider）；无新定时器、监听、公共状态机或UI。
