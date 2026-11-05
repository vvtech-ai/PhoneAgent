# 正式构建演练边界增量核验

## 当前增量：Android Profile（2026-09-21，e4c2f77）

本节覆盖下方历史“匿名导出待定/安卓未恢复登录”的旧描述：用户只要日志上传；安卓登录已有真实复用证据。此次只读产物，没有设备安装、短信、外呼或账号访问。

正常`lib/main.dart`构建Profile，显式传`ENABLE_MIGRATION_PREVIEWS=true`，仍受`kDebugMode`编译门禁。构建74.0秒成功；未改Gradle、生产签名或Release保护。产物是`build/app/outputs/flutter-apk/app-profile.apk`，SHA256：`8435C6B50460F4310A599E018562EDCF3AA8AC7FA66001134D86A29FB12CC131`。

- `aapt dump badging`：包名`com.vvtech.aiassistant.dev`，versionCode=1、versionName=1.0.0，application-debuggable。Profile不是去调试权限的生产Release。
- `apksigner verify --verbose --print-certs`：V2通过，Android Debug证书，SHA256 `266accf5018522a4400644be5a2067f58fd8c3fca358d6c76144412799e266aa`。不能用于覆盖原正式App。
- 只提取`lib/arm64-v8a/libapp.so`（13,763,488字节），逐一按UTF-8和UTF-16LE匹配既有`scripts/web/audit-release-previews.mjs`导出的11个forbiddenMarkers和8个requiredMarkers：演练标记保留0，正常入口缺失0。正向对照防止把空文件或错误产物当作通过。
- 证明范围仅为本arm64 AOT中的已知字符串，不等于所有MOCK资产清除、整个调用图不可达、其他ABI/iOS产物或真实交互通过。未因它勾选Android增量真机任务。
- Kotlin守护编译出现跨C/E盘增量缓存异常，构建自行回退后退出0；没有删除缓存或强杀进程。另有Java源级别弃用、CupertinoIcons字体警告，原生系统控件/图标检查中保留注意，不将构建成功当作图标验收。
- 字体警告补充取证：本机固定Flutter3.32的`material/app.dart:976`在Inspector的tapBehavior按钮引用`CupertinoIcons.cursor_rays`；`widgets/app.dart:1829`附近只在assert中挂载Inspector。自有lib无CupertinoIcons调用，不能据构建警告直接断言业务页缺图标，也未证明这是唯一警告来源；不为消警告盲目加依赖。实际系统控件仍依第M13项查看。

复验入口（普通开发不必重复本构建）：

```powershell
flutter build apk --profile --no-pub --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://agent.vvtech.tech/aiassistant-api/ --dart-define=ENABLE_MIGRATION_PREVIEWS=true -t lib/main.dart
aapt dump badging build/app/outputs/flutter-apk/app-profile.apk
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-profile.apk
```

使用已有Android SDK/JBR；不得将这份Profile产物当普通Debug恢复包或生产升级包。当前两端手机上的普通包不受此次构建影响。

## 历史Web Release证据（保留当时范围）

2026-09-21，基点23a2606加本批；范围为共享附件结果处理和正式main的Web Release产物，不是全迁移或原生Release验收。

## 发现与修正

原Debug编译开关已经隐藏正式导航中的演练入口。实际Web Release文本复核仍发现附件处理器保留“MOCK · 选择文档场景”等合成分支；这证明打包残留，不证明普通用户能从隐藏菜单进入。

在`conversation_attachments.dart`的文档/OCR演练结果分支各增加同一`migrationPreviewsEnabled`短路。关闭时直接返回，不创建合成页面、不落入正式文档选择；开启Debug时保留原演练。正式相册、文档导入、历史恢复与原有开发者工具不变。

## 验证

- 新增2项正式App弹层结果测试，直接覆盖文档/OCR演练枚举，避免只验证隐藏菜单。关闭/默认开启两次运行各10项定向：附件结果、完整文档/OCR到历史恢复、开发者可见性/交互、三个宽度主导航；为10项各运行两种配置，不计为20项独立用例。
- `flutter analyze --no-pub`无问题，4.0秒；Node标记审计3项通过，含空产物拒绝、逐个禁止标记及Dart Unicode/Latin字节转义解码。脚本仅读文本、不执行JS。
- 正式`lib/main.dart` Web Release编译29.7秒通过。特意设置`ENABLE_MIGRATION_PREVIEWS=true`，11个已知演练入口/附件场景标记均不在产物中；8个原开发者、身份、文档及解锁串正向对照均存在。不能把这些标记当全部路由行为证明。
- 输出在忽略目录`.local/release-boundary/web`，未覆盖8080/8122；配置为`APP_ENV=prod`与`https://synthetic.invalid`，是无真实账号的隔离启动检查，不是可交付业务环境。首次基线编译误用不支持的APP_ENV=test，仅作为打包残留线索；已用有效prod配置重编译，未改配置校验或接真实生产账号。
- 最终main.dart.js SHA256：`39FE7AC9FA3C932E80956B4CF3BA4A588713E7344194B2AFCE9BE2AE734146DA`。
- 临时本机8124静态服务实际加载Release产物，浏览器截图确认品牌、手机号/验证码输入和登录按钮正常显示，无配置错误页；未输入或请求验证码。检查后关闭临时页/服务，不动已有8080/8122。

## 重复执行

```powershell
flutter test --no-pub --dart-define=ENABLE_MIGRATION_PREVIEWS=false test/attachment_preview_boundary_test.dart test/shell_attachment_workbench_test.dart test/features/settings/developer_preview_visibility_test.dart test/features/home/shell_navigation_test.dart
node --test scripts/web/audit-release-previews.test.mjs
flutter build web --release --no-pub --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://synthetic.invalid --dart-define=ENABLE_MIGRATION_PREVIEWS=true --output=.local/release-boundary/web
node scripts/web/audit-release-previews.mjs .local/release-boundary/web/main.dart.js
```

默认Debug演练兼容测试用相同test路径、不传关闭参数。不要为普通页面修改每次重跑构建或全部测试。

## 未通过或未执行的范围

本次未安装Android/iOS，不发送短信/身份/外呼、不读取真实账号存储。Android只读安装时间仍为2026-09-20 22:27:05，与用户“尚未手动恢复”一致，不能声明登录复用成功。

编译仍有CupertinoIcons字体族提示；项目自有lib未检索到CupertinoIcons引用，但这不足以证明依赖路径不受影响，保留为iOS样式/图标阶段核对项。本次没有修改依赖或仅为消除提示添加字体。

仍需补同版本双端页面阶段、真实系统布局和持久化、匿名诊断导出归属、生产签名/完整旧数据升级及集中人工能力验收。共享控件可选preview参数可能保留其他MOCK文本；不将所有MOCK字符串等同可达假业务，也不宣称整个正式发布审计完成。
