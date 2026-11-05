# 可信地区与当前位置选择验证

2026-09-18，OpenSpec `overseas-translation-ui` 1.6。完成的是定位/区号共享交互与双端端口，不是实时翻译或迁移整体完成。

2026-09-21增量：[旧定位缓存迁移](LEGACY_PREFERENCES_MIGRATION_VALIDATION.md)已补生产双门禁装配，保留国家及原采样时间，新值优先/串行/失败重试；51项相关定向、analyze与Android Debug编译通过，未安装。下方“导入仍待专项”仅代表09-18历史状态，实际同签名升级仍待验。初始化最新确定两步，不再等待第三步选择；其他媒体当前状态见[MIGRATION_HANDOFF](MIGRATION_HANDOFF.md)，不按本文历史待办重复实现。

## 来源与边界

- Android固定v65 `4c781e3`：`DefaultTranslationRegionRepository`、`AndroidTranslationRegionRepository`、`DialCountryLocationState`、`TranslationCallSettingsModels`。实际地区与拨号国家、服务部署区域独立；失败保留可信缓存，无新增过期规则。
- iOS固定 `ddb996a`：`iOS/PhoneAgent/PhoneAgent/Core/Services/AILocationService.m` 的CoreLocation/CLGeocoder路径；不复制原实现的坐标日志或全局pending覆盖风险。
- 用户批准现有HTML/CSS与共享组件先完成交互；复用国家列表/搜索/返回，新增定位状态区。未做最终视觉测量或宣称双端视觉一致。
- 只有用户点击“获取”才请求系统授权和位置；Web正式端口不支持，不访问浏览器定位。国家页读取的是环境/API隔离的设备缓存，无账号HTTP。坐标只在原生一次定位和系统逆地理编码过程中使用，不跨Dart通道、不存储、不打印；系统地理服务本身可能联网。

## 实现与状态

| 层 | 文件/职责 |
|---|---|
| Domain | `translation_location.dart`：可信国家ISO/时间、结果分类、来源/存储端口；没有UI和系统依赖 |
| Dart状态 | `TranslationLocationController.load/locate/openSettings/cancel`：仅读缓存、单飞、保存失败可见、缓存回退、退出代次隔离；普通/翻译共用 |
| Data | `SecureTranslationLocationStore`仅写schema/countryIso/sampledAtMs；`TranslationLocationChannel`校验返回、请求ID、100秒上限和定向取消 |
| 平台薄端口 | Android `TranslationLocationChannel.kt`；iOS同名Swift：权限、定位、逆地理编码、设置、超时/取消，不包含模型/拨号规则 |
| 装配/页面 | `translation_location_providers.dart`；`DialLocationHost`注入纯`DialCountryPage`，两个正式拨号Route复用 |
| 演练 | `PreviewTranslationLocation`仅合成来源和内存缓存；`TranslationLocationPreviewPage`与正式国家页、Controller、Host共用 |

流程：打开国家页→只读缓存→点击获取→权限/一次定位/逆地理编码→共享校验及持久保存→展示当前位置→**用户点选后**才返回区号。没有自动拨号、自动换语言或拿US服务节点当美国位置。

拒绝可再次获取，不能再请求权限时可去设置；返回设置后显式获取，不自动弹权限。失败可保留“上次可信位置”；未支持区号（如合成DE）明确提示，不新增拨号国家目录。读取失败可重试或重新获取；保存失败保留当次成功位置但告知未持久。页面确认pop就取消，不等返回动画结束才dispose；请求ID保证旧取消不关闭新请求。

Android API30及以上用可取消的getCurrentLocation，低版本限时requestSingleUpdate；API33及以上异步Geocoder，低版本在专用线程解析。粗略权限可用网络定位，精确权限额外允许GPS；系统定位服务或地理解析不可用时明确失败，不把IP/语言/SIM当位置。系统实现参考[LocationManager](https://developer.android.com/reference/android/location/LocationManager)、[Geocoder](https://developer.android.com/reference/android/location/Geocoder)。iOS使用每次请求独立manager、一次requestLocation及stopUpdatingLocation取消；对应[Apple请求定位说明](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation())。

## 自动验证与浏览器

- 新增24项：Controller12、通道/存储5、Widget7；全量 **1,534项通过**。analyze无问题，684个Dart文件格式检查无修改，19项OpenSpec校验通过。
- Web Debug、Android测试环境Debug、Mac Xcode15.2/iOS无签名构建通过；均使用APP_ENV=dev及正确`/aiassistant-api/`上下文。没有真机安装，构建不能替代权限/定位验收。
- 首轮Widget发现返回动画期间晚到仍可能写缓存，改为PopScope即时取消后测试通过。全量首轮发现原开发者菜单测试假设条目已构建，改为滚动查找后全量通过，没有删除测试。
- 浏览器独立8099：合成US定位时CN仍是当前区号；点击位置才返回US；重开显示缓存；“需去设置”保留可信缓存、模拟设置后要求明确再次获取。页面持续MOCK标记；未访问真实位置、系统设置、账户、电话或费用。
- 入口：开发者功能演练→当前位置与区号演练；独立入口 `tool/previews/translation_location_preview.dart`。可选美国/中国/未支持地区/拒绝/需设置/定位失败/缓存读写失败。旧拨号MOCK不挂真实定位Host，专用演练才注入合成端口。

## 集中人工验收

1. 获准安装本批标准包后，两端普通/翻译拨号→国家地区。仅进入不得弹定位权限，手选/搜索仍可用。
2. 点击获取；Android分别允许粗略/精确位置，iOS允许使用期间位置。成功只展示当前位置，原区号不变；点当前位置才选择。
3. 首次拒绝、永久拒绝/系统关闭权限：观察拒绝或去设置状态；从设置返回后点击获取才能重试，不能偷偷重复请求。
4. 系统位置关闭、逆地理编码离线、超时：显示失败；已有缓存显示上次可信位置，不能伪造新采样或覆盖手选区号。
5. 获取中立即返回、再进入；旧回调不得跳页、改区号或写入晚到位置。两端后台/系统回收、权限弹窗时退出也要检查。
6. 成功后重启读取缓存；安全存储锁定/失败必须可恢复，不输出坐标或国家以外的地址数据。旧Android位置缓存导入仍待OTA迁移专项，不覆盖旧App数据。

## 剩余范围

模型准入/海外设置显隐尚未接本状态：必须同时接v65 `testControlsEnabled && forceBackendWebRtcForTesting`开发者例外，不用半实现禁用现有流程。倍率须从账号翻译provider响应获取；首次初始化第3步仍待既有产品确认。真实create/media-ready/merchant-call、媒体、归档、全局音频及双端真机/视觉继续在原待办中。此批没有重启已登录8080、发短信、改变Mac保留screen或修改签名。
