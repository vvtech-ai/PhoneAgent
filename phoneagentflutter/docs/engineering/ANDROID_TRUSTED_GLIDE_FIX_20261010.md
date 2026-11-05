# Android可信身份展示Glide依赖修复

## 原因

用户diagnostics-9中的两次androidMainUnhandled与设备15:30:05、16:10:32崩溃吻合。16:10:31.903 SDK getIdentityToken code1成功且ticket非空，随后DraggableFloatView.dealDoubleHead→setCover→initView因com.bumptech.glide.Glide缺失NoClassDefFoundError，未能展示悬浮身份。与先前code103“没有找到相应令牌”不同，本次是宿主展示依赖遗漏。

参考Android固定0f8879e4 app/build.gradle469–470已有Glide与compiler4.15.0，Flutter原依赖和APK均缺失。只读审计两个厂商AAR字节码确认15个Glide外部引用，包括Glide、RequestBuilder/Manager、转换、缓存、监听和Target；未更改SDK。原始日志/号码/令牌未提交。

## 修改

Gradle加入Glide4.15.0和annotationProcessor compiler4.15.0，保留参考版本。SDK直接调用Glide，不依赖宿主GlideApp；无需新增kapt。APK守卫从4个SDK关键类扩展到19个，按DEX class_defs核验实际定义，保留runtime哈希/AAR重复类/原组件与角色permission检查。没有改变业务流程、SIM规则、权限、开关或iOS。

## 验证

- 旧APK扩展守卫RED：原4个SDK定义存在、15个Glide定义缺失。
- 新APK及公司签名后APK均GREEN：19个定义各一次、哈希/重复类/组件通过。
- Gradle debugRuntimeClasspath实际解析Glide4.15.0。
- Android可信JVM7组21项0失败，Dart可信109项通过，analyze11.7秒无问题。
- Debug测试包2026101010构建46.5秒；APK包名com.vvtech.aiassistant.dev，测试环境配置沿用。
- 首次默认debug证书与原公司证书不一致，系统拒绝覆盖，原App保留。采用本机现有公司配置重新签名，证书与此前测试artifact一致并签名verify通过。
- USB --no-incremental -r覆盖安装成功，安装后versionCode2026101010，firstInstallTime仍2026-10-10 15:14:38，lastUpdateTime16:49:14，安装后启动成功。未卸载/清数据。

仅定向验证，未跑全仓回归。签名材料/密码仅本机私有配置及进程环境，不提交。外部pubspec.lock保留。OpenSpec未归档。

## 待验

已请用户在修复包确认登录保持并触发一次真实来电，核对身份悬浮窗、头像及无闪退。安装和构建不等于真实来电展示通过；尚无本修复包真实来电结果，继续待验。不自动发真实电话/短信/认证。
