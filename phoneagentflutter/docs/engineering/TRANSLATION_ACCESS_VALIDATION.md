# 翻译模型准入、倍率和开发者设置验证

## 范围与依据（2026-09-18）

本批完成共享 Dart 的模型准入/设置显隐、正式开发者翻译偏好、账号倍率读取和隔离 Web 演练，不是实际翻译媒体或整体迁移完成。

行为依据固定 v65 `4c781e3` 的 TranslationCallEffectiveSelectionPolicy、TranslationCallRoutePolicy、TranslationCallSettingsRepository、AssistantTranslationDebugSettingsSection、AssistantProviderRuntimeController、AssistantModelBillingMultiplier 和 TaskApiService。

| 可信地区 | 有效强制海外 | 模型可选 | 地区呼叫门禁 | 普通海外设置 |
|---|---|---|---|---|
| 未知 | 否 | 否 | 拒绝 | 隐藏 |
| 未知 | 是 | 是 | 仍拒绝 | 隐藏 |
| CN | 否 | 否，国内 SIP 不迁移 | 拒绝 | 隐藏 |
| CN | 是 | 是 | 地区允许，媒体未接仍不拨出 | 隐藏 |
| 非 CN | 任意 | 是 | 地区允许，媒体未接仍不拨出 | 显示 |

有效强制 = 构建允许调试且持久偏好开启。构建值沿 v65 默认 true，可用 `ENABLE_TRANSLATION_WEBRTC_TEST_CONTROLS=false` 关闭；不是仅 Debug 或仅测试环境。开发者入口仍要求进程解锁。手选区号、倍率和测速不改变可信位置；定位失败后保留可信缓存，没有新增过期规则。源副标题“固定 US”与实际策略矛盾，遵循实际 serviceRegion，强制开关不改节点。

## 实现及接口

- `domain/translation_access.dart` 是纯 Dart 策略；`app/translation_access_providers.dart` 组合可信位置与偏好。
- `TranslationPreferences`/codec/`TranslationSetupController` 增加 forceBackend；旧 schema 1 无字段兼容 false，非布尔值不启用。继续环境隔离、设备级偏好、串行保存及失败重试。
- `DeveloperToolsRoute` 正式接强制、US/JP、GPT/Gemini；未解锁不读取设置，构建关闭不显示/消费强制。其他工具仍明确 MOCK。
- 正式拨号/模型弹层共用准入；海外设置路由持续检查显隐。跨弹层/国家页/设置导航继承调用方容器，防止演练进入真实来源。
- `ApiTranslationBillingRepository` 仅 GET `api/account/settings/realtime-translation-provider`，沿 AccountApi 的 **X-Account-Id** 契约；不是 Bearer 保护列表成员，不改后端鉴权。节点 languages 是另一套无账号凭据 GET。
- 归一 providers 海外别名，仅显示正且有限的 billingMultiplier，格式 `×一位小数`。失败可重试，无有效值不伪造默认值，不据 available/configured 改地区规则，不发 PUT。加载/依赖重建隐藏旧值，按账号代次隔离晚到。

纠正旧记录“没有可用模型接口”的过宽表述：海外选项/准入基于本地目录与地区策略，没有使用独立节点模型可用性查询；**账号 provider 配置接口存在，提供倍率**。目录、倍率和测速都不证明媒体或电话就绪。

## 验证

- 新增24项：地区/强制/构建开关、缓存、codec及持久失败；倍率归一/无效值/GET账号头/账号晚到；开发者门禁；正式跨页、未知地区阻止呼叫、重试与依赖重建。
- 最终1,558项测试通过、analyze无问题、698文件格式无改动；Web、Android Debug、Mac iOS Debug无签名构建通过，均测试环境。构建不等于签名安装/真机验证。
- `tool/previews/translation_access_preview.dart` 提供手机宽度演练（本机8100）。复用正式路由/策略；位置、倍率、目录、测速、联系人、拨号、偏好均替换为内存来源；账号API访问抛错；外层持续MOCK标识。
- 浏览器验证CN手选+1仍禁选；强制/JP/GPT返回保留且真实地区仍CN；未知位置呼叫被拒；US显海外设置；倍率失败不显示估算、可重试。检查控件可达，不宣称视觉精确验收。
- 初轮页面测试误用不存在的关闭tooltip，修正为已有dial-close key。鉴权测试初稿误期望Bearer，核对源与AccountApi后按真实账号头契约修正，没有改生产鉴权迎合测试。

## 集中人工验收与剩余

1. 批准阶段安装后，两端复用登录；国家页明确点击定位，检查拒绝/设置重试/可信地区。测试地区场景不伪造生产位置。
2. 解锁开发者，修改强制/JP/模型，返回拨号、重开和重启核对保存；关闭强制恢复实际地区规则。构建关闭时持久true也不生效。
3. 授权测试账号读取真实provider配置，对比倍率；断网重试、换账号无旧倍率。无需发电话/认证/扣费。
4. 实际媒体接线后再验证下一通生效、forced CN路由和未知地区仍拒绝；这部分当前**未完成实现**，不能用演练代替。

剩余初始化第三步决策、LiveKit/AppAudio媒体/事件/归档、其他开发者消费者、双端阶段安装和视觉校准。本批无真实定位、电话、短信、账号写入或新安装；8080原登录和Mac保留解锁screen未修改。
