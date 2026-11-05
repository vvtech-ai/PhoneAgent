## 设计
对齐aiassistant_app与AIAssistant1的DefaultTranslationRegionRepository。已有可信位置刷新时维持resolved，refreshing标记异步生命周期，busy继续防重复定位和设置操作；拨号只要求可信位置，后台刷新不拒绝。失败保持resolved/cache；首次定位仍locating。诊断区分后台刷新标志，不改变安全白名单。
## 验证
位置controller、国内拨号、访问页和日志定向测试及analyze/OpenSpec；真实外呼不执行。源码按每批最多3文件，测试独立批，当前其他修改保留。
