# 验证记录

## 范围与来源
2026-10-28用户确认本会话修改计划并要求执行。起始test_v1.8.0_fix@f285726b干净；附件明确字号11、Regular400、浅色#B0B4C3/100%、深色白色/34%。20dp安全区额外底距、键盘8dp和仅本说明不缩放为用户确认的计划，不称截图实测间距。

本轮仅PhoneAgent Flutter展示层，无接口/身份/状态owner/原生/依赖变更。保留按钮、标签、颜色、业务门禁及回调，继续使用既有共用控件。未切分支、提交、推送、打包、安装或真实拨号。

## 实现和适配
- AiContentNotice提供显式light/dark构造，Text固定11/w400/normal/居中、TextScaler.noScaling，正常字体跟随原系统配置；其他文字的MediaQuery与TextStyle不变。
- 任务对话双模式共用浅色说明，收起键盘20dp/弹出8dp额外底距。Scaffold拥有键盘避让，SafeArea拥有安全区，各一次；仅因Scaffold会消费正文viewInsets，使用所属View检测键盘存在，不自行叠加高度。
- AI任务通话底部安全区内20dp；深色说明不再被挂断不可用状态叠加.38透明度。按钮自身禁用行为和外观保留。
- 翻译通话继续SafeArea+20dp，说明在可滚动控件之外固定显示；短屏、大字和展开拨号盘滚动上方控件时，说明不跟随滚动。
- 正常宽度一行；极窄自然居中换行，无ellipsis/截断/缩字。

## 自动验证
| 验证 | 实际结果 |
|---|---|
| 修改前新样式/底距期望 | RED：33项失败 |
| 初步适配（修正键盘检测后） | 49通过 |
| 10文件适配与直接调用方 | 117通过，约11秒，非全量回归 |
| flutter analyze --no-pub | 无问题 |
| OpenSpec | 本change strict通过；全仓269通过、0失败 |
| diff/文件大小 | git diff --check通过，修改的手写文件均≤500行 |

117项包含：call_ai_content_notice_test、ai_content_notice_page_layout_test、conversation_ai_content_notice_test、call_pages_test、translation_call_page_test、translation_session_pages_test、v66_conversation_composer_test、tts_composer_control_test、native_conversation_system_keyboard_test、conversation_navigation_test。
覆盖Android/iOS主题，320/360/390/430逻辑宽度，最短480高/长屏，安全区0/34，像素密度1/2/3，系统字号1/1.3/2，语音/文字切换、键盘升降及草稿保留，翻译拨号盘展开，挂断中和终态，极窄40dp换行及无障碍非操作语义。断言说明实际字号不缩放、其他标签正常缩放、居中位置、准确底距、浅/深颜色及无额外Opacity祖先。

## 工具与恢复
最初Flutter test按既有配置解析依赖，完成后Git确认pubspec及lock无变更；后续使用--no-pub。首轮24项键盘断言失败后重新核对Scaffold消费viewInsets的实际布局，以单文件修正检测，不更改期望或全局键盘行为；复验通过。未出现设备操作或有副作用的外部请求。

## 待验
未取得实体Android/iOS设备截图、系统实际键盘和视觉验收；widget主题/尺寸模拟不称真机验收。无原生或构建链变更，本轮未打包安装、不启动真实通话。保持active不归档。

## 最终校验
flutter analyze --no-pub无问题（6.6秒）；10文件117项定向全部通过；OpenSpec全仓269通过0失败；git diff --check、UTF-8及修改Dart文件500行上限检查通过。未执行全量回归、构建、安装或实体设备操作。

## 2026-10-28 iOS非零安全区间距追加
- 授权：用户明确确认三处说明计划并执行；起点test_v1.8.0_fix@2a9ec798干净，保留当前分支，不修改原生/依赖/接口及状态owner，不提交推送。
- 规则：仅iOS所属View原始底部安全区>0，说明上方gap+10（翻译17，任务通话/对话18）；键盘关闭额外底距10（安全区34时屏幕底距44）。Android/iOS零安全区仍20，键盘打开仍8，11号/字重/颜色/居中不变。
- 职责：共用AiContentNotice仅判断原始View条件，不叠加安全区；原页面与共用控件各应用对应gap，SafeArea与Scaffold仍只避让一次。六源码按3+3微批，测试独立，格式化机械批。
- RED：首次新增输入上gap断言使用TextField内框，边框造成1dp偏差；只读核对后改测所属ConversationTextDock外框，没有调整产品边框。正确测量下旧实现48通过/16失败，仅iOS非零安全区新期望失败。
- GREEN：两份整页几何测试64通过；包含双平台、320/360/390/430宽、短屏/长屏、系统1/1.3/2字号、DPR1/2/3、0/34安全区、键盘/草稿/语音切换及拨号盘/挂断禁用/终态。校验说明底边、上gap和正常高度下按钮原坐标，短屏说明不随拨号盘滚动。
- 调用方扩大：12文件125项通过，覆盖共用说明、Android系统栏与SafeArea、两类通话页、共用输入及系统键盘；与64项存在重叠，不累加。flutter analyze17.5秒无问题。非全量；无原生/平台/依赖改动，不构建安装。
- 设备画面与真实系统键盘待验；未做真实通话、音频、安装、提交或推送，不归档。

- 本轮最终校验：OpenSpec272通过/0失败，git diff --check、UTF-8及500行检查通过。HEAD仍2a9ec798，无提交推送；真机待验。
