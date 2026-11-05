# 设计

对照依据：aiassistant_app AssistantDeveloperToolsPage.kt、DeveloperLocationCountryPicker.kt、AssistantDeveloperPermissionPageHost.kt、AssistantTranslationProviderSettingsPage.kt、DefaultTranslationRegionRepository.kt。

模拟 ISO 保存至已有按环境隔离的安全翻译偏好，默认空值兼容历史配置。有效地区 Provider 将模拟值覆盖真实地区状态；真实 GPS/cache Provider 保留。国家列表来自现有 SDK directory，按名称/ISO 搜索，展示绑定支持模型数；自动定位和返回区分处理。设置模拟时清除旧 forceBackend，不改被叫国家/语言/拨号模型 ID。权限 Controller 通过动态回调识别模拟地区，不请求真实定位，仍执行通话记录权限链。

账户模型调试使用现有按账号和地区隔离的 repository/controller，服务器 GET/PUT 仍传 DOMESTIC/OVERSEAS；其偏好独立于拨号目录 modelId。进入刷新，切区/换号销毁旧 controller 防迟到写回。

采用职责拆分：正式 route、国家选择页、模拟控件、账号调试页、共享操作行。手写文件保持 500 行内。每业务微批最多 3 源码文件。列表操作继续使用现有 controller，权限重置保留原生实际打开翻译拨号行为而非仅按文案推断。

验证：定向设置/权限/翻译地区和模型测试、Flutter analyze、OpenSpec；不发真实认证、外呼或扣费。不修改并行 iOS SDK 更新。

原生 DialCountrySelectorPage 在 DebugOverride 下隐藏设备当前位置快捷项，Flutter DialLocationHost 同步隐藏；隔离定位预览显式不读取正式模拟状态。有效地区只订阅模拟 ISO，账户设置只订阅有效国家，避免保存/真实定位状态变化重复创建账户 controller。账号设置可用按钮遵循服务端 available，configured 单独展示；成功提示同步原生。
