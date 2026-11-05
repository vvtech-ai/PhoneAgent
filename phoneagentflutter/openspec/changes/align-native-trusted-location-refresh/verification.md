
## 2026-10-12 对齐原生可信位置后台刷新
- 用户明确授权对齐原生Android已有可信位置后台刷新仍允许拨号；change align-native-trusted-location-refresh。状态保持resolved，refreshing独立生命周期且busy仍防重复定位/设置；失败保留可信缓存，无可信位置仍等待。国内准入按可信CN判断；访问loading仅在无可信位置且busy时成立。诊断补充real/effective/selectedRefreshing白名单布尔字段。
- 状态/controller/access微批3文件；国内预检/诊断接线/诊断白名单微批3文件；测试独立2文件，格式化机械批。手写源码均小于500行，无新例外；保留工作区其他修改，不提交推送。
- Flutter3.32 analyze无问题；位置controller、国内拨号、双端位置加载/页面/访问页、诊断及app_logs定向146项通过，非全量回归。覆盖可信CN刷新中准入、刷新单飞、取消后迟到结果不写入、无可信位置等待和失败缓存回退。OpenSpec97项及diff检查通过。
- 未构建安装或真实外呼；iPhone新包复现待验，不把自动测试表述为真机通过，不归档。
