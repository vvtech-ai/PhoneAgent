## ADDED Requirements
### Requirement: Android可信环境必须覆盖登记测试Release
Android启动初始化与通道 SHALL 共用环境策略，登记test包在不可调试Release仍为test；生产不可调试包为pro，未知包 MUST 拒绝，Dart/原生环境不一致 MUST 拒绝。
#### Scenario: 测试Release进入可信设置
- **WHEN** com.vvtech.aiassistant.test不可调试且APP_ENV=test
- **THEN** 启动与通道均使用test，不因Release误选pro

### Requirement: 首页可信引导仅Android
系统 SHALL 仅在Android已登录、账号同步完成、首页可见及前台时，对未展示/未禁用/未打开过SDK的用户延迟约300ms展示一次引导；离页、切号、退出及销毁 MUST 取消失效操作。展示和打开记录 MUST NOT 作为真实授权证据。
#### Scenario: 首次首页
- **WHEN** 用户满足条件
- **THEN** 展示可信通信被叫引导并持久化seen，去授权复用设置SDK入口
#### Scenario: 关闭与禁用
- **WHEN** 用户关闭、点击遮罩或返回
- **THEN** 展示可稍后在设置开启的单按钮提醒，之后不重复首页引导
- **AND** 不再提示持久化disabled并直接关闭
#### Scenario: iOS登录进入首页
- **WHEN** iOS恢复登录或新登录成功
- **THEN** 不自动展示首页引导，保留账号同步与条件齐备后的SDK推送绑定

### Requirement: 设置打开完成语义必须区分平台
Android打开 SHALL 只表示SDK启动调用已发出，MUST NOT 因该回复立即读取所谓返回后状态；iOS SHALL 保留SDK退出后完成及刷新。两端 MUST NOT 把打开成功作为授权成功。
#### Scenario: Android启动SDK
- **WHEN** SDK启动调用返回
- **THEN** 不添加宿主Activity等待或强制关闭，也不立即查询授权
