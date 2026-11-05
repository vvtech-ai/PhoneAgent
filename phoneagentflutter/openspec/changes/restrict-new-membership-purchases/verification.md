# 验证记录（2026-10-26）

## 范围与源码
Flutter基线fff1ef3f，Java基线50574b40；当前feature/test_v1.8.0_zys。仅新报价/新订单资格、现有按钮及固定提示；core、购买分类、支付材料、验单、入账、退款与原UI未修改。无数据库迁移或协议变更。

## 修改前证据
- Flutter新增资格矩阵及按钮测试：64通过、52失败，失败覆盖重复/短周期/低等级、未知会员及新文案。
- Java新报价测试：V2禁购报价未抛拒绝异常；legacy重复购买继续进入旧续购路径（合成无term产生NoSuchElementException），未在资格层拒绝。
- 以上为本地自动回放和机制证据，不是线上现场根因或真实渠道证据。

## 实现与保持
- Java独立MembershipPurchaseEligibility；legacy/V2报价各一处调用，新订单在幂等原单/待支付原单返回及旧报价哈希校验之后调用。积分包跳过。
- Flutter独立只读资格计算；newPurchaseEnabled用于新购，purchaseEnabled继续作为原有进行中结账技术检查，避免支付期间会员变化丢失反馈。
- 原同SKU新购断言按用户决策改为报价前拒绝；旧队列/历史解析/支付断言保留。渠道开关测试补齐明确免费会员事实；恢复测试选择合法高等级套餐，保留错误、查询、次数及恢复断言。
- 同等级长周期仍执行原RENEW/AFTER_QUEUE，未引入时长合并或新周期标识；更高等级仍执行原UPGRADE。

## 自动验证
- Flutter `flutter test --reporter expanded test/features/commerce`：949通过、0失败，退出0。
- 随后补充同级长周期原支付分支、保留/排队不参与资格、进行中检查独立三个用例；两份定向测试130通过、0失败，退出0。
- Flutter `flutter analyze`：No issues found，退出0；补充测试后变更文件Dart analyze同样通过。
- Java JDK17.0.18，Maven离线`-pl aiassistant-sdk-api -am -Dsurefire.failIfNoSpecifiedTests=false test`，选择commerce/membership下非数据库门控测试及core时间线/退款：SDK391、core9，共400通过、0失败、0跳过，退出0。数据库门控测试未选入，不冒充真实MySQL验收。
- 两仓 `openspec validate restrict-new-membership-purchases --strict` 与 `git diff --check`通过。
- 既有commerce_visual_test定向捕获375px页面，加载中文字体，1用例通过；截图检查当前会员置灰、固定提示、协议和客服完整，无遮挡。新增按钮测试覆盖375/390/430和1x/2x字。截图为合成数据，不是真机。

## 未执行
未部署、未写业务数据库、未发起真实支付/退款/电话、未核对安装包。未改原生，不将本地回归称为Mac原生构建或真机验收。无共享编排规则变化，不声称三端规则同步。
