# 设计与验证范围

- 基线：PhoneAgent codex/dev@96203c88，开始时工作区干净；未确认实际安装包，本次不打包或安装。
- owner：MembershipRoute负责入口策略；MembershipPage保留共用控件和现有样式；App根部iosCommerceRecoveryProvider与PurchaseController继续持有自动恢复状态。
- 变更：会员页显式传入showRestore=false，不再为了按钮查询Apple历史；保留既有历史provider、恢复回调、验单和交易监听。
- 接口与身份：不变更订单/验单接口、账号生命周期、appAccountToken、订单号或transactionId。支付成功与发货成功仍按现有合同区分。
- 不变量：正常购买、启动/前台/网络恢复/交易更新补单、持久记录、账号隔离和finish条件保持。任务编排回放不受影响。
- 验证：空历史、Apple历史、账号切换、待同步交易及同步成功后均不显示按钮；已有自动恢复测试和支付等待测试回归；运行Flutter analyze、OpenSpec校验和diff检查。无原生改动，不以Dart测试声称真机支付已验证。
