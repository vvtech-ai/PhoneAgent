# Android可信来电三项参考对齐

用户2026-10-10逐条确认页面生命周期、账号退出/切换、单双卡规则与参考Android一致，随后批准计划执行。固定参考0f8879e4baf1d56fe6d7f8f356101fdf61d602ed；来源为AIAssistantApplication、AssistantAuthRuntimeController、TrustedCalleeSimNumberBridge。不修改参考项目或SDK二进制。

| 范围 | 修改后的行为 |
| --- | --- |
| SDK页面 | 首次openIncallUi，后续SettingActivity失败回退；启动调用完成返回桥接结果；SDK管理页面返回 |
| 生命周期 | 移除SDK Activity跟踪、25秒启动等待、launchGate、防重复SDK启动与强制finish；账号或引擎释放只释放桥接上下文 |
| 账号/SIM | 有效账号及打开SDK时同步；退出/换账号/引擎detach不清空SDK SIM，不清未计划写入的槽位 |
| 持久数据 | 删除Flutter SIM ownership/journal代码，旧journal不再读取或执行清理；不清用户数据或SDK偏好 |
| 检测 | 始终尝试SDK槽位，订阅API在READ_PHONE_STATE或READ_PHONE_NUMBERS任一具备时尝试，异常按原生回退 |
| 号码顺序 | SDK local仅null时读取SDK sim，号码无效再订阅info.number、line1Number；不额外采用API33 getPhoneNumber分支 |
| 单卡/双卡 | 单卡空号用登录号；双卡写真实号码，空号仅槽1优先否则最后槽使用登录号 |
| 写入 | 先反射两参数SPUtil.set，否则SPUtil.put(key,number)，不写空号 |

桥接consumer/owner/token字段保留用于匹配Flutter调用和避免过期通道写入，不触发SDK页面关闭、SDK号码清理、开关或系统角色修改。共享Dart控制器请求去重只覆盖在途通道调用，SDK启动后不等待其页面退出。

## 验证

- Android可信JVM7组21项，0失败/错误：SIM计划、权限OR、null/blank回退、退出/detach保留号码、只写计划槽、旧通道拒绝、guide及依赖字节码。
- Flutter可信模块109项通过；analyze9.3秒无问题。
- Android Debug构建12.3秒通过；APK守卫确认runtime哈希、AAR无重复类、4类实际DEX定义、SDK原接收器/筛选服务启用及角色permission。
- OpenSpec72项、diff检查通过。仅定向验证，未执行全仓回归；未更改iOS，不重打iOS包。

移除已废弃launchGate、号码归属清理生产实现及验证旧行为的测试，替换为用户批准的新契约测试，不能拿旧测试总数衡量通过范围。每个源码微批<=3，所有修改源<500行。pubspec.lock为外部修改，保留不提交。

## 待验

尚未在相同Android手机/SIM/角色权限下运行首次/后续SDK页面返回、换账号/退出、双卡和后台/锁屏真实来电对照。构建及测试通过不等于这些设备场景已通过；本批无真实电话、短信、认证或费用，不归档。后续真实来电验收需明确设备与操作条件。
