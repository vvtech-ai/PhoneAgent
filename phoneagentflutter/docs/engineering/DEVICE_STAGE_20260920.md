# 2026-09-20 阶段设备与连接验证

## 后续iOS阶段增量（15:43核验）

- **Preconditions**：继续原已解锁screen，使用Xcode15.2和固定Flutter3.32；独立临时源码目录保留原工程不覆盖。基点9c33967加本轮两个Swift双工文件和共享工厂平台门禁，三文件Windows/Mac SHA-256一致。
- **Build / Install**：先无签名编译111.2秒通过；最终dev环境flutter run签名编译68.8秒、安装启动57.5秒成功。Bundle ID为com.chaken.phoneagent.test，codesign --verify --deep --strict通过，出现Dart VM Service。
- **User Actions**：无需新解锁/Apple ID登录/拔插。iOS当前显示登录页，不把安卓已有登录当成iOS已登录，不重新发送验证码。页面交互可后续通过隔离MOCK验收。
- **Expected Logs**：Xcode build done、Syncing files to device、A Dart VM Service；签名valid on disk / satisfies its Designated Requirement，均已观察。
- **Forbidden Logs**：本阶段未观察安装签名失败；后续Lost connection to device、capture/output错误仍需据日志定位，不宣称已做完整错误日志扫描。
- **Pass Criteria**：真实截图`.local/stage-validation/ios-stage.png`显示登录表单，顶部/底部未见裁切；仅证明启动及登录页，不代表全页面一致。测试范围是8条工厂/运行时/PCM通道定向测试，analyze无问题；没有再打Android包。
- **Failure Follow-up**：真实双工声音、回声、采样率切换、蓝牙/听筒/扬声器、锁屏/中断及服务端收件未测，按APPAUDIO_TRANSLATION_VALIDATION集中人工执行。调试会话保留，后续网络优先用原主机名并严格校验原SSH密钥。

下方为本日较早的Android阶段记录，关于iOS未编译/未安装的历史状态由上方增量覆盖。

## Preconditions

- 源码基点 f4137cc；本批未修改正式lib/Android源码。两个既有Swift双工草稿仍未编译，不据此称iOS已完成。
- 用户明确批准保留数据覆盖PhoneAgent Dev；仅com.vvtech.aiassistant.dev，不卸载、不清数据、不覆盖原安卓正式App。
- 安卓覆盖前force-stop/启动仍进首页，证明已保存登录可恢复。未打印或导出凭据、未重新发送短信。

## Build / Install

- Flutter3.32，Android Studio JBR；执行 `flutter build apk --debug --no-pub --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://agent.vvtech.tech/aiassistant-api/`，9.4秒成功。
- APK包名com.vvtech.aiassistant.dev，versionCode=1，versionName=1.0.0-foundation；新旧APK均V2校验通过，SHA-256签名证书一致。
- 阶段APK SHA-256：`BA2E46D27B2210705B0C0C559E6B1F030EBAB69C35733CF7B9149AA0DB9EBDBE`。
- `adb install -r`返回Success；设备lastUpdateTime为2026-09-20 15:26:42，不再是9月16日旧包。
- 覆盖后再次force-stop/启动，直接进入已登录动态首页，显示积分和Seeduplex通话模型。UI截图 `.local/stage-validation/android-home.png` 留本地不提交；“今日登录赠送”提示不是验证码登录页。

## User Actions

- 本批安卓操作已自动完成，无需验证码。
- Mac已经恢复连接，无需用户重新登录Apple ID或重插iPhone。后续阶段操作先明确Xcode15.2路径；不关闭保留的screen会话。
- 安卓模型/设置/任务/统一页键盘及iOS当前阶段安装仍继续验证；本记录只证明安卓覆盖和首页启动，不代表全部页面一致。

## Expected Logs

- 安装：`Success`；冷启动：MainActivity启动且UI出现首页/任务/设置。
- Mac SSH：`MAC_REACHABLE`；`xcodebuild -version`为Xcode15.2/15C500b；`xctrace list devices`列出iOS16.7.16真机。

## Forbidden Logs

- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`、`INSTALL_FAILED_VERSION_DOWNGRADE`、`FATAL EXCEPTION`、`Lost connection to device`应作为失败调查，不清数据绕过。
- 不把`devicectl: No devices found`独立当成手机未连接；需交叉确认xctrace与USB。
- 本批未采集启动错误日志，只观察启动与UI，不能声称上述日志扫描全通过。

## Pass Criteria

- **已通过**：Dev包签名一致、保留数据覆盖、冷启动复用登录到首页；未重新发短信。
- **已通过**：MacSSH网络恢复、同主机身份验证、Xcode15.2可执行、iPhone与USB被识别。
- **未完成**：本阶段iOS编译/安装、两端全页面比较、真实音频及外部能力；不以首页截图代替。

## Failure Follow-up

Mac原IP192.168.1.49不可达，Windows同网段且ARP未获得目标MAC。按已有主机名VVTechdeiMac-804.local解析到192.168.1.51；用StrictHostKeyChecking=yes及原HostKeyAlias=192.168.1.49核验通过后，SSH成功且hostname/whoami一致。原因是连接地址已变化，不是Xcode登录或钥匙串失败；地址变化的分配机制未调查，不断言DHCP具体原因。

系统xcode-select当前指向CommandLineTools；/Applications/Xcode.app是旧11.1，当前可用15.2位于/Applications/Xcode_15.2.app。后续进程显式设置DEVELOPER_DIR，不在本批修改系统全局配置。devicectl未列设备，但xctrace与system_profiler均确认iPhone存在；保留screen 42442.phoneagent-build为Detached。
