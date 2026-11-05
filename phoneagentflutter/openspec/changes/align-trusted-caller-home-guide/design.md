## 来源与边界
Android参考aiassistant_app 8f23592的AssistantLowRiskEffects、AssistantAuthRuntimeController与V88GuideDialogs；UI辅助参考AIAssistant1同名源码。AIAssistant当前iOS仅保留首页UI未接线，本轮明确不补iOS首页引导。当前源码分支codex/dev_zys，保留其他工作。

## 环境
纯Kotlin统一环境策略：登记`.test`及`.dev`使用test，生产包不可调试时pro，未知包拒绝；启动及通道共用策略。Dart继续校验自身APP_ENV，与原生不一致仍拒绝。测试包含不可调试`.test`，不改变签名或生产构建门禁。

## 引导生命周期
feature-first拆分存储端口、状态控制、UI宿主。Android原生私有prefs存全局seen/disabled，与参考设备全局语义一致；SDK已打开记录/旧authorized标记也可抑制首页引导，但绝不据此判定实际授权。入口读取和写入均验证当前账号归属；存储失败不假成功。应用已登录且账号同步完成后，首页可见、前台、无覆盖页时延迟300ms；离开/切号/销毁使旧异步结果失效。展示即记seen，关闭/遮罩/返回显示单按钮提醒；不再提示写disabled。使用共用NativeGradientAction/NativeBusinessDialog和Flutter底部弹层；不引入SDK权限控制。

## SDK入口契约
复用TrustedCallerSettingsEntry：Android只确认启动调用完成，不新增Activity等待、超时或强制finish，不立即readStatus；iOS仍在SDK退出后刷新。引导点击先关闭自身，使用同一入口，页面归属保护保持。

## iOS核验
PhoneAgentApp持续监听账号，恢复完成与登录成功均自动updateAccount；通知允许且APNs环境匹配才注册；owner/token/权限齐备后bootstrap，再bindRid手机号+token。合并初始化、串行解绑和迟到保护已有实现，不为核验重写。账号交付成功不能证明远端绑定完成。以Dart和Foundation合成测试验证，无真实SDK操作。

## 验证
OpenSpec全量、flutter analyze、可信模块及Shell直接调用方定向；Kotlin环境/引导策略、iOS Foundation绑定和环境测试。设备权限/SDK页面/推送远端效果待验，不打包安装。Shell原499行，本轮仅接线，超过500时必须拆职责而不新增例外。
