# 单路通话共享页面与演练

## 历史恢复增量（2026-09-17）

沿用演练工具栏新增“恢复合成历史”，直接调用正式restore；仅合成外部端口持有内存历史和通知。已在浏览器验证首次不足→恢复保留三条历史消息且无自动弹框→再次输入弹框→返回无新用户消息。14项回归覆盖恢复资格、同任务身份继承及余额/关闭边界。正式页面未新增按钮，视觉仍后置；真实设备/跨设备通知存储未据此验收。

## 失败与实时结果增量（2026-09-17）

沿用既有菜单/统一页/回执组件，增加模型超时与实时结果两个隔离演练入口，不新增产品页或样式。共享控制器按v65区分结构化错误，终态回执校验当前命令/callId后收起本地观察。浏览器已验证模型超时后文字输入/发送可用、实时结果直接回统一页；合成边界始终显示。新增27项/全量723项、analyze、Web/Android Debug构建、19项OpenSpec通过。视觉校准、真实后端/电话/媒体及本批双端设备证据均未据此宣称完成。

## 最新执行入口增量（2026-09-17）

正式ConversationRoute现已复用CallSessionPage，单路实时请求自动进入，多路留统一页；共享Host承接不足弹框/返回和结果收起。新增call-flow-interactions.json记录入口、状态和验证边界，不重新绘制样式或复制页面。

新增整链路演练只替换外部端口，不接网络/媒体；浏览器验证单路进入→结束等待→结果返回、多路留页和积分弹框。27项新增/696全量测试通过。实际媒体/双端与视觉仍待完成，后文旧“未装配”说明只代表共享页面初始批次；最新边界以CALL_FLOW_VALIDATION.md为准。

## 来源与决策

行为固定v65 `4c781e3`：FinalAiCallPageV3、AiCallHeaderPresentation、CallMonitorPlaybackState、CallMonitorAudioRoute、AiCallAudioSourceSheet。设计固定`0cd58de9`：pvCallScreen、v63-0-1.js的installCallControls/sourceIcons、v63-0-1.css和v63-0-4.css。旧callPage静音/接管/额外结果按钮及隐藏波形不迁移。

用户授权静态HTML/CSS和组件先完成交互，因此运行态视觉校准暂后置，不把源码参数冒称computed DOM测量。页面不解释设计JSON，不绘制整页截图或透明点击覆盖层。

## 产物与架构

- TargetAppConfig.json：Flutter现有工程、SafeArea、不画系统栏，验证命令。
- component-tree.json：页面、转写卡、三按钮、音源sheet的来源/布局/样式/资源和差异。
- interaction-contract.json：合并记录RouteGraph、PageStateGraph、ActionableControlInventory、InteractionMap及AssetManifest，4路由5边、13状态、6组关键控件全部有事件映射；是构建期文档，不是运行时渲染输入。
- 2个page/route文件、3个widget文件、1个展示模型、1个演练Controller、1个纯内存Repository。生产CallSessionController未复制也未改变；媒体模拟与真实业务provider完全分离。
- UI采用真实InkWell/Button/ListTile、Navigator和modal sheet，系统返回正常pop；dispose清理计时和本地观察，不挂断后台电话。

## 资源和组件参数

| 组件 | 源与实现 | 待校准/排除 |
| --- | --- | --- |
| 顶部模型/目标/状态 | pvCallScreen + v65；13/30/15字号、左右18；CONNECTED计时，终态单独展示等待/结束 | CSS最新增量隐藏旧独立计时，未重复渲染旧状态栏 |
| 转写 | v65卡片，圆角20、内边距16×15、间距10、正文14/21 | 新快照自动滚至底部，计时刷新不抢滚动；滚动列表铺满剩余高度 |
| 三按钮 | v631控件，52圆、24图标、8标签间距，danger #EF4444 | listen/hangup/earpiece/speaker/bluetooth五组SVG直接引用源path，存于call_icons.dart；不是Material近似或Unicode |
| 音源sheet | v65底部弹层，圆角28、左右22；听筒/扬声器/条件蓝牙 | 原型点击循环被v65真实弹层规则覆盖；关闭不丢原页面 |
| 系统区 | SafeArea，动态高度，短屏标题滚入列表 | 排除设计设备边框/系统栏/Home Indicator；底部按钮锚定可用区域 |

模拟工具栏是显式验收附加层，不作为产品设计还原；未来真实入口不传previewHeader。5组SVG已消费5组；页面与控件事件可访问，但未进行像素差值测量，不给虚假高保真百分比。4类语义组件均有布局/样式映射，无fallback截图。

## 验证与未完成

新增12项回归：号码/状态投影、合成轮询/挂断/等待结果、监听错误/静音/重连/晚到清理、320/390/430宽UI、蓝牙条件与取消、系统返回和失败重试。全量448项通过，analyze无问题，Web和Android Debug构建通过，OpenSpec18/18。

正式自动确认/积分/ledger协调、监听票据到播放/实际音源、双端真机和视觉仍待办；此批共享页由开发者隔离入口可达，不声称真实外呼主流程已经完成。实现/集中人工步骤见SINGLE_CALL_VALIDATION.md新增章节。
