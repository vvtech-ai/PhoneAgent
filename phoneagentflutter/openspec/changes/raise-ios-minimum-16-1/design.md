## 方案
以16.1作为App/扩展/本地Pod和Pods构建最低值，保留高于16.1的依赖要求。AppFrameworkInfo同步，防止构建元数据宣称12.0。通知扩展生成器同步避免重生成回退。新增源码配置检查；pod install只刷新本地podspec校验，不升级依赖。
## 验证
OpenSpec、配置检查、pod install、签名Profile构建和成品Info.plist版本核验。与来电修复共用构建，旧15.5签名产物不安装，重新构建16.1再覆盖安装。
