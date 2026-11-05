# 身份资料迁移验证

## 数据/状态批次：2026-09-16

来源固定 v65 `4c781e3`：UserIdentityModels、MyIdentityScreen、MyIdentityValidation、UserIdentityScreenSaveUseCase、AssistantContactRuntimeController、AssistantApiService、AssistantRootAndTextPolicy。

- GET/DELETE `api/assistant/user-identity?userId`；POST 普通资料清洗；已认证 PATCH 只发 userId/gender/contactPhone。
- EMPTY 优先于认证标记；只有后端 VERIFIED + 非空姓名才显示认证。姓名上限128、联系电话可空，非空遵守旧版大陆手机号规则。
- 草稿保留旧职业/说明字段，但不据 DTO 新增已经不使用的表单入口。
- 加载/编辑/保存/删除互斥；未加载不可写；已认证姓名不可改；保存失败保留草稿；未确认不删除；删除失败保留资料；dispose 后不应用结果。
- 首次保存停留，已有资料保存返回设置，以类型化 outcome 提供给下一批 route。

验证：`scripts/verify.ps1 -SkipAndroidBuild` 成功；144 项测试、analyze 无问题、OpenSpec 12/12。新增10项均使用合成账号和 HTTP adapter，不发送真实身份请求、不输出资料/凭据。

本批无依赖、原生或构建配置变更。未运行新设备安装：上一批普通入口构建/安装命令被执行策略拦截，未通过其他命令绕过。当前模拟器仍是上一批测试入口；不是普通 App 交付。iOS 未验证。

## 未完成

页面与设置接入、首次引导、删除后模型/音色刷新与跳过状态；SDK、替换、声音克隆；真实账号/双端验收。未验收不归档。

## 页面批次：2026-09-16

已接设置→我的身份，加载失败重试、空态填写、资料详情、已认证标记、编辑/保存、删除确认；声音克隆按 v65 入口跳模型配置页，本批不实现认证/克隆流程。删除成功失效模型缓存，后续从服务器加载当前选择。

固定设计五态提取109节点/12组交互/3个SVG；computed fill/stroke烘焙为独立资源，不依赖网页CSS。禁止截图UI。参考 `design/identity` 全套产物。

`verify.ps1 -SkipAndroidBuild`：149项测试、analyze、OpenSpec12/12通过；13份设计schema通过。新增Widget测试覆盖失败/返回/只读/确认和小屏大字+220键盘遮挡；资源注册后测试正常加载。无真实账号写入。

上一节未完成项中的“页面与设置接入”在本批完成；首次引导、删除跳过状态、认证媒体清理和删除期间离页后的跨模块刷新仍待协调。设备受既有策略阻塞，未构建/安装本批APK；没有声称Widget等价真机验收。iOS与真实账号未验证，不归档。
