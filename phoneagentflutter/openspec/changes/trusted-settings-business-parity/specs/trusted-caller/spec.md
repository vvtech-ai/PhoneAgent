## ADDED Requirements
### Requirement: 可信设置必须确认当前账户同步而不依赖授权查询
入口 SHALL 等待应用级当前账户同步确认再准备SDK，串行同步 SHALL 拒绝过期目标结果且失败可重试；授权查询 MUST NOT 作为打开前置，不展示加载中间route。
#### Scenario: 同步延迟和换账号
- **WHEN** 同步等待期间当前owner改变
- **THEN** 旧结果不能打开SDK或将新owner标记同步成功
#### Scenario: 同步失败再次点击
- **WHEN** 当前owner同步失败后用户重试
- **THEN** 重新同步当前owner，反馈明确阶段，不伪报读取授权状态失败
### Requirement: 平台首次流程必须匹配参考业务语义
iOS SHALL 按账号记录说明，展示前标记并保持说明到SDK退出整体返回设置；Android SHALL 使用全局首次展示记录并在首次SDK调用前标记，复用Application初始化及后续Activity失败回退SDK入口。
#### Scenario: iOS开始和SDK退出
- **WHEN** 首次说明点击开始
- **THEN** 不先退回设置页，SDK退出后结束本次说明流程返回设置
#### Scenario: Android首次调用异常
- **WHEN** 首次SDK调用抛错
- **THEN** 已看引导事实按参考调用前写入，不当作证书授权证明
### Requirement: SIM缺失不得成为额外入口阻塞
Android SHALL 对无卡/无读取权限/无号码执行参考可用号码策略，空写入计划不额外阻止SDK；跨账户未知旧写入清理失败 MUST 保留阻断。
#### Scenario: 无可用SIM
- **WHEN** 当前有效账户没有可写SIM号码
- **THEN** 可继续SDK设置，由SDK处理授权，不伪报SDK状态查询失败
### Requirement: 设置诊断必须保留脱敏原生失败阶段
可信设置 SHALL 记录固定阶段/错误白名单/环境/耗时，可持久化导出且不包含账号/号码/密钥/token或任意异常文本。
#### Scenario: 平台准备失败
- **WHEN** 原生返回SDK_ACCOUNT_UNCONFIRMED或SDK_PREPARE_FAILED
- **THEN** 保留白名单错误码及prepare阶段，用准确提示反馈并支持定位

### Requirement: Android可信SDK运行时必须完整打包
Android SHALL 在工程本地保存参考运行时依赖并使用implementation打包，校验必要类在APK中的实际定义；初始化错误 MUST 仅暴露固定安全类别。
#### Scenario: 运行时缺类
- **WHEN** APK缺少ChakenNetworkConfig或Builder定义
- **THEN** 产物校验失败，不能仅凭编译通过宣布可用
