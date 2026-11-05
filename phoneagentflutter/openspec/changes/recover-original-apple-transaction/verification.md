# 验证记录（2026-10-23）

## 范围与基线
- Flutter：codex/dev，基线 8c8afeec0818100b4a572a15387d01f1e0b18fec；保留已有通知头像相关未提交改动，不纳入本变更。
- Java：feature/test_v1.7.0，基线 8bb0a0b97d5192b687f5ead3dc29badc95b12afb。
- 实现验证阶段未部署、未修改订单或数据库，未追查正式验单首次失败。

## 失败证据与实现
- APPLE-MONEY-01：完整 USD 原币回执在现金兼容投影不同后无法读取/重放；内部现金参数可影响验单。新增用例先失败，修复后通过。金额与币种仍做格式/范围校验；不限定 CNY，不与业务报价判等。完整原币回执一致性只比较原交易与原币事实，缺失原币的历史数据保留旧兼容规则。
- 原币 JSON 回执不再把现金派生值当权威；Web 管理列表、统计及核验 SQL 同步生成。已有非空 cashPaidFen 数据库/响应字段保留兼容，外币对应的 0 不作为实际支付金额；实际金额以 platformPaidCurrency/platformPaidAmountMilliunits 展示。未迁移历史现金数据。
- APPLE-RECOVERY-01：未完成交易未阻止创建新订单；先失败后通过。新桥接返回商品 ID，按商品恢复；旧桥接缺少商品身份时保守先恢复。
- APPLE-RECOVERY-02：verified 同商品旧 token 不再被原生直接丢弃；由同账号 verifier 交服务端查原单。新订单只结束本地购买流程、保留迟到支付恢复；关闭失败仍显示新订单供查询，不声称未付款。
- APPLE-RECOVERY-03：UUID 大小写导致完成交易后的本地 attempt 未清除、共享验单 Future 可能绕过调用方的 expectedOrderNo；两项均先复现再修复。账号失效不 finish，重复回调不重复交付。
- 原生和 Flutter 已确认 StoreKit 价格比较保留；不改 Android/第三方支付或商品快照权益规则。

## 自动验证
- Flutter 3.32.0：flutter test --no-pub --reporter expanded test/features/commerce：825 项通过。
- Flutter analyze --no-pub：commerce 源码及本次三个测试文件，无问题。
- JDK 17.0.18，Maven：SDK Apple 相关测试与 Web 金额/订单查询回归合计 130 项，118 通过，12 跳过，0 失败/错误。跳过项为 ApplePlatformMembershipMySqlTest（8）及 CommercePlatformAmountsMySqlTest（4），未配置受保护的隔离测试库；不能声称已验证 MySQL 运行语义。
- 两仓 openspec validate recover-original-apple-transaction --strict：通过。
- 生成的 Web Mapper XML 可解析；生成器与核验 SQL 同步，git diff --check 通过。
- Xcode 26.3：flutter build ios --debug --no-codesign --no-pub：成功，含修改后的原生桥接。构建自动生成的 Podfile.lock/project.pbxproj 差异已还原，不纳入本次修复。

## 未执行与交付边界
- 未运行真机/沙盒实际购买、失败重试及退款；未安装新包，未部署 SDK/Web。
- 未运行隔离 MySQL 集成测试；相关测试代码已补充且编译通过。
- SDK 与 Web 原币回执读取应配套交付，旧 Web 读取逻辑依赖现金派生字段。
- 状态：源码与本地自动验证完成；真实支付和数据库验收未完成，不归档。

## Flutter Git 交付
- 用户授权提交 codex/dev 并推送 origin/codex/dev，仅包含本次 Apple 内购修复、测试和规格。
- 已快进同步远程 d38ce10f，本地通知头像诊断及其文档改动完整保留，不纳入本次提交。
- 配套服务器修复已推送至 feature/test_v1.7.0，提交 9b85ec2cb；未部署服务或安装新包。
