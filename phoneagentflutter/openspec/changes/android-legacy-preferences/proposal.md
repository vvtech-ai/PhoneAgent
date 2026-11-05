## Why

Android同包OTA需保留现有偏好。旧登录导入已有，但Flutter翻译/原音安全存储为空时直接返回默认值，未读取固定v65偏好。

## What Changes

- 仅生产Android同包/精确prod API允许从固定旧SharedPreferences读取保留字段。
- 导入拨号翻译开关、提示、双方语言、双模式地区、海外模型/节点/强制偏好及原音设置。
- 补充设备级身份初始化跳过标志，仅导入已有选择，不开启或改变初始化页面流程。
- 补充定位确认国家缓存：仅translation_region_state的国家ISO和原采样时间，进入现有位置安全存储；不读取坐标或用拨号区号替代。
- 新值优先、串行首次导入/写入、失败可重试，保留旧文件。不迁移国内SIP/历史界面/权限授予假状态。

## Capabilities

### New Capabilities
- android-legacy-preferences: Android同包升级的有效偏好导入。

### Modified Capabilities
无。

## Impact

Android薄读取通道、翻译/原音及身份初始化跳过三个Dart存储/provider；无后端、数据库、SDK、音频、权限申请或真实用户数据操作。定向测试与Android Debug编译，真实同签名升级另验。其余旧录音/本机记录不由此子批代替。
