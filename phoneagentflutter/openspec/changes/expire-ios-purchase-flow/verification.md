# 验证记录（2026-10-22）

## 范围与行为

Flutter 基线 9d35f0eb，后台基线 3d5230dda；未切换分支、未提交或推送。仅 iOS / APPLE_IAP 新增行为，Android 既有支付规则、页面、文案和恢复间隔保持。既有自动过期测试“未知 Apple 永不结束”按用户本次批准的新规则修改断言，保留并扩展原并发、付款优先、租约及账号占用保护。

服务端仍要求 expanded schema 和 COMMERCE_PAYMENT_RECOVERY 开启，按原 expiresAt 到期后由后台扫描执行（30秒扫描、首次45秒及有效租约会影响实际执行时点），不是精确第900秒强制取消。未改支付渠道配置。无已知交易号时无法服务端主动查 Apple；依靠 token 绑定通知和 StoreKit unfinished/updates。已知交易号的本地超时关闭单按1小时退避查询。

接口不增加新枚举或数据库列；safeErrorCode=APPLE_PURCHASE_TIMEOUT 标识本地到期，事件记录 closedAt / expiresAt。它不是 trustedClosed 证据。验单成功清除超时展示原因，超时审计事件仍保留。迟到会员冲突沿既有恢复入口，不改变会员报价或自动默认权益。

## 已执行

- Flutter 3.32.0 / Dart 3.8.0：flutter test --no-pub --reporter expanded test/features/commerce，809项通过。包含新 IOS-EXPIRE 单元与页面回放、原 IOS-WAIT、取消启动补报、会员/积分/Android支付回归。
- Flutter analyze --no-pub：通过，No issues found。
- JDK17.0.18 / Maven3.9.14：mvn -q -pl aiassistant-sdk-api -am '-Dtest=Apple*Test,Commerce*Test,MembershipApple*Test,MembershipFulfillmentServiceTest' -Dsurefire.failIfNoSpecifiedTests=false test；SDK选定测试315项，265通过、50跳过、0失败/错误。新增边界与渠道隔离断言后再次运行四个直接受影响服务测试，全通过。
- python3 scripts/commerce1837/check_apple_expiry_mapper.py：使用真实 XML SELECT 和合成内存 SQLite 表验证恢复选择、退避、新旧订单冲突及 Android 条件隔离，通过。此项不是 MySQL 实际事务验证。
- git diff --check、Mapper XML解析、OpenSpec文件 UTF-8 和8项场景结构检查通过。OpenSpec CLI未在当前PATH中提供，未声称CLI验证通过。

## 回放证据

IOS-EXPIRE-01/02：超时事件仅一次，关闭后取消保持 CLOSED/原因；客户端读到关闭或补报返回关闭均清理待办。
IOS-EXPIRE-03：查询期间付款先提交则不关，CLOSED 后有效 Apple 付款推进 SUCCEEDED 并清除原因；无成功事实不伪造付款。
IOS-EXPIRE-04：迟到 Apple 付款保留金额与原单身份、占用冲突显式进入恢复；真实查询验证不清后来订单的占用。完整双单真实交易仍待沙盒/隔离库验收。
IOS-EXPIRE-05：关闭后的尝试转 closed 持久阶段，重启不作为购买阻塞；迟到成功继续原验单/finish，迟到取消清理待办；存储失败不丢原记录、不抛未处理错误。原账号切换与等待回放通过。
IOS-EXPIRE-06：原单无支付/关闭按钮，有原控件查询入口；会员反馈手动查询可执行，自动计时不轮询关闭单；可重新申请新报价。
IOS-EXPIRE-07：过期临界点、有效租约、付款字段及履约字段检查；失效租约/已记录交易/已付款不关闭。多实例真实数据库竞争未执行。
IOS-EXPIRE-08：服务端关闭方法对 ALIPAY 不生效、原查询间隔仍15秒；Android标签和查询资格不变，原支付测试保持通过。

## 未执行

50项数据库集成测试因未配置隔离数据库环境而跳过。未连接业务数据库、未做真实 Apple 沙盒/Ask to Buy、未启动真实后端、未构建安装包、未做真机截图与实际扣款。未修改原生 Swift/Android平台文件、依赖、工具链、签名或发布配置。代码完成不代表线上已生效；不归档本变更。
