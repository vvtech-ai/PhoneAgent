# 联系人Tab入口修正（2026-10-09）

## 范围与原生依据
用户确认执行，仅联系人Tab权限、弹窗、切换与刷新。固定Android0f8879e4、iOSbb9ff349；不修改参考仓库源码或其他业务。原生入口分别是AssistantNavigationActions/AssistantRootContactPermissionRuntimeShell及AIMainTabBarController/AIContactsTabPermissionPolicy。

## 实现
| 状态 | Android | iOS |
|---|---|---|
| 已授权 | 选中并刷新 | 完整/有限授权选中并刷新 |
| 未授权入口 | 保持原页，深色说明“允许 Phone Agent 使用通讯录权限？”、“用于获取联系人信息”，拒绝/允许 | 未决定保持原页，白色“允许访问通讯录？”、“用于选择联系人并发起通话任务”，暂不/继续授权 |
| 说明取消 | 只提示需要权限，不请求系统 | 同左 |
| 系统拒绝 | rationale可重试仅提示；不可重试显示设置引导 | 显示设置引导 |
| 已拒绝再次点击 | 仍按原生先说明/显式申请后判断 | 直接设置引导，不重请求 |
| 主动设置返回 | 静默检查，允许才切换，否则提示 | 同左 |

权限契约独立于联系人列表，authorization/requestAuthorization只查询或请求，不枚举联系人；保留既有load契约。Android薄通道返回实际canRequest，iOS保留有限/受限。入口独立单飞协调器，连续点击不重复；其他Tab、Shell入口代次、覆盖路由、账号及销毁保护迟到结果。设置恢复事件早于启动返回时排队且只消费一次。
Shell只接线，492行，未超过500；新增协调/弹窗/门控按职责分离。入口统一刷新，Shell内ContactsRoute不重复mount/前台读取；门控前台静默刷新即便详情覆盖也保留，防止撤权后的旧选择。独立ContactsRoute仍默认原有加载/恢复行为。演练明确替换权限端口，不借真实平台默认授权。

## 运行对照
iOS固定实际权限Dialog和Policy在独立参考包编译，只链接纯展示/策略与Masonry。Common无障碍仅最小兼容层，确认回调为空，不请求系统权限或设置。Flutter纯宿主运行生产入口门控，合成权限与目录，无插件/服务。实际验证取消保留首页高亮、合成授权后进入、拒绝转设置引导、模拟设置授权返回进入；两倍字号说明及授权进入已操作通过。
iOS初次弹窗安全区导致中心下移约14点，改为全屏居中后原生/Flutter中心一致。原生46点按钮、Flutter至少48点，卡高约2点差异保留，不宣称逐像素一致。
Android直接原Compose V88PermissionDialog及AssistantContactPermissionSettingsDialog，安装前清空24个业务String并移除业务权限；Flutter专项包com.vvtech.aiassistant.ui.contactstab零Android权限、无业务插件。两个弹窗已运行截屏对照，深色卡最大300宽及Material设置窗口分别处理，保留系统安全区/字形行盒/48热区差异。Qemu窗口未在CUA可用App列表出现，Android未实际点击Tab；完整入口交互为双平台组件测试，iOS另有实际操作证据。
原图与元数据在ignored .local/ui-reference/contacts-tab-evidence和ios-contacts，截图不提交。独立包不安装真机、不替换普通App、不卸载或清数据。真实系统授权/有限选择器及真机设置往返仍待验；无真实备注、认证或外呼。

## 验证与恢复
定向验证覆盖权限协议、平台分支、取消/拒绝/设置返回、重复点击、设置返回竞态、账号/其他Tab迟到、详情覆盖撤权、双平台普通/2倍字号及实际安全区居中；联系人及Shell直接调用方结果在收尾补充。不以该范围当整App全量。
正常Android debug及iOS无签名Debug宿主编译通过；隔离原生Android构建1分27秒，iOS实际固定权限UI编译通过，Flutter双端隔离构建通过。最终普通产物恢复另行记录。
首测试误将loginEpoch当StateProvider，核对定义改显式合成状态；详情覆盖测试默认Finder跳过offstage，核对堆栈后仅测试指定skipOffstage=false；合成设备最初仍返回硬编码authorized，按实际测试结果改为可变状态后撤权专项通过。两处大括号lint修复；一次外部翻译页lint随后主线程修复，未改该文件。固定3.32的AlertDialog不支持constraints参数，读取实际编译错误后去除、保留支持的窗口参数，未升级SDK。
iOS参考首次模拟器未Booted拒绝执行；核对启动完成后再运行。首次固定源导出未声明include目录而拒绝，读取导出规则后只声明Contacts与Contact策略目录再成功。Android首次沿旧参考身份安装遇版本降级而失败，未卸载/降级重放；改专项独立身份并通过权限校验后安装，旧Flutter参考保留。真实授权/设置未执行。
GitLab此前多次403；收尾读取并发任务记录发现已成功推送的新证据，本轮将恢复正常推送核验，不改凭据。active change待用户验收，不归档；外部pubspec.lock保留。

## 最终结果
- 联系人目录与Shell直接调用方整组166项通过（22秒）；最后仅调整弹窗呈现方式后入口12项通过（包含新增淡入不缩放测试，11项重叠，不合计178）。
- flutter analyze --no-pub无问题（3.5秒）；Python参考安全4项通过（0.094秒）。OpenSpec与diff最终校验见任务记录。
- iOS采用淡入淡出，Android深色说明即时呈现，Android设置使用Material弹窗；运行原图为布局与先前流程证据，最后呈现方式的验证为定向测试，不伪称录制过动画视频。
- Android设置卡对照原生218–398与Flutter217–399（320×640），文字/按钮基线约3–5点差异；深色卡均最大300宽，固定Compose继承0.5字距已同步。普通字号保持原生有效风格，48热区和大字号适配是明确保留差异。
- 修改原生通道，现有旧安装包热重载不足；需使用新构建进行保留数据安装后验收。此次未安装普通App或真机，真实系统权限/设置及有限选择器仍待验。

最终普通Android7.5秒、iOS无签名8.3秒构建通过；产物身份分别核对为com.vvtech.aiassistant.dev与com.chaken.phoneagent.test。OpenSpec49项通过，git diff --check通过；不混入并发翻译模型UI或pubspec.lock。

实施提交07781d3已成功推送codex/dev_zys，Git确认HEAD与upstream一致；先前403已恢复。本轮未改认证。普通App/真机未安装，真实权限/设置验收待完成，active不归档。
