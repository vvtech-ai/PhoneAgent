# 设计与改动边界

## 源码事实与目标偏差
Flutter fff1ef3f、Java 50574b40；检查时均为feature/test_v1.8.0_zys且工作区干净。未核对实际运行包或部署，本次只交付源码及本地验证。现有按钮固定购买会员；Java PAUSE_QUEUE_V1允许同周期及低等级报价。此为机制证据，不称现场复现。

## Owner、入口与身份
- Flutter：domain统一计算按钮资格，CatalogState及MembershipCheckout消费；依据服务端MembershipCurrent.level/currentMonths，未知状态不放行。按钮组件只展示。
- Java SDK：独立资格规则，仅用于legacy/v2新报价与新订单插入前；使用服务端Effective及当前pricingMonths。
- 身份：accountId、productId、quoteId、requestId、membershipBeforeHash；原有账号隔离、报价哈希与请求幂等保留。
- 新建订单先返回相同请求原单或待处理会员原单，再检查新购买资格。支付/恢复/发放不接入限制。

## 保留的规则
不改CommercePurchasePolicy或MembershipQueuePolicy的购买分类，不改core、日历、权益队列、周期标识、赠送积分及退款；不承诺同级长周期立即改变现有当前周期。仍按当前实际生效套餐判断。无新API、字段、协议版本、迁移或额外提示。

## 文件职责与验证范围
新增Java MembershipPurchaseEligibility只判断资格；三处购买入口调用。新增Dart membership_purchase_eligibility只读服务端事实；catalog_controller统一门控；membership_offer仅改按钮与固定提示。
购买资格完整矩阵、未知周期、保留会员、报价和下单绕过、原单幂等/占位、积分包不受影响、375/390/430及大字体布局、既有支付及履约回归。关联需求T01-T06/T09/T12-T13/T16-T18/T24-T25（仅本次购买限制及展示部分），编排ENTRY-03/MODEL-03/CONFIRM-01-02/HISTORY-01保持；无改动的语音、真实通话和平台支付不冒称已实测。
