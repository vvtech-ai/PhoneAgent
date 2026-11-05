## Context
用户批准全环境检查。当前 Debug/Profile 为测试 Bundle ID，Release 为正式 Bundle ID；dev/test 共用身份、phoneagent-test Scheme 和专用域名，不能承诺三 App 共存隔离。历史 fix-ios-invite-associated-domains 的设计仍作为来源，本 change 显式更新环境选择与成包门禁。

## Decisions
- 使用 PHONEAGENT_IOS_ENV=dev/test/prod 显式选择邀请配置；Debug/Profile 默认 dev、Release 默认 prod，构建前核对 Dart APP_ENV，不能仅凭构建模式猜实际环境。
- prod: ioslink.chaken.ai / www.chaken.ai / phoneagent / com.chaken.phoneagent。
- test: phoneagent-ioslink.vvtech.tech / chakenai-test.vvtech.tech / phoneagent-test / com.chaken.phoneagent.test。
- dev: phoneagent-ioslink.vvtech.tech / chakenai-dev.vvtech.tech / phoneagent-test / com.chaken.phoneagent.test。
- dev/test 继续兼容旧分享域名 agent.vvtech.tech；网页主域名按环境设置。专用唤起域名必须独立保留，网页关联不替代它。
- Debug 权限文件仅增加关联域名，不增加生产推送等无关权限；Release 保留已有推送及通信通知权限。
- 不改变 Bundle ID/扩展身份或证书。Release/test 若仍使用正式 Bundle ID，构建失败并要求提供既有测试身份签名配置，不能自动改应用身份。
- 签名成包检查是邀请配置专项门禁，不替代平台完整验证；必须读最终权限及 embedded.mobileprovision，不能用源码设置代替。现有临时构建任务通过 run-test-build.py 的完整平台验证阶段调用它。

## Validation
合成输入回归验证环境串用、原问题重复域名、缺失权限、错误 App ID/描述文件/邀请 Scheme；Xcode 三构建模式 × 三环境 showBuildSettings 核对展开值；Flutter 邀请定向测试、analyze、原生回调编译验证、OpenSpec。真实 IPA 可只读验证，不重签名；未执行新的构建安装、冷/热启动或注册不勾选验收。
