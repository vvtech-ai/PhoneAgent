# 普通拨号：静态设计先行交互批次

2026-09-17 用户允许先使用已有 HTML/CSS/组件补齐交互，视觉统一校准。此批不声明视觉验收。

## 来源与范围

- memory/index.html 的 engine-dial；css/engine-dial.css；设计 commit 0cd58de9bb578845517aeb54bef8ab6970392b81。
- Android v65 DialCountryCatalog、DialPhoneNumberPolicy、ContactDialNumberPolicy、AssistantRootCallEntryActions 为行为基线。
- 样式来源：24px 水平内边距、19px 号码、3×4 矩形分隔键盘（矮屏55/其他64）、24px 数字、9px 字母、62px 绿色呼叫按钮、52px 关闭/删除区域。
- close/call/delete 三个原始 SVG 路径落地 assets/images/shell/dial_*.svg，分别由 DialerPage 引用。无整页截图、无系统状态栏伪绘制。
- 地区页复用项目列表/搜索组件，国旗暂用国家名称，不虚构资源；视觉待校准。

## 路由和控件契约

| 入口/控件 | 动作 | 状态/返回 |
| --- | --- | --- |
| 底栏拨号 | push 普通拨号 | 关闭 pop，输入在本登录会话保留 |
| 联系人电话 | 校验国家/号码后 push、预填姓名号码 | 无效号码显示明确错误，不发起拨号 |
| 国家地区 | push 搜索页 | CN/JP/SG/US；搜索名称/拼音/区号，选择 pop，取消不变 |
| 数字键 | 更新输入 | 数字最多14位；*#保留；输入变更清除姓名 |
| 删除 | 删除一位 | 长按清空 |
| 拨号 | resolve 后调用 SystemDialer | busy 防重入；打开/不支持/失败，不推断接通 |
| Web 演练 | 显式打开独立 MOCK 拨号页 | 常驻标识；仅内存结果，不调用平台或后端 |
| 返回/关闭 | pop 当前路由 | 国家选择返回拨号，再返回来源页 |

## 未覆盖，禁止计入完成

2026-09-17最近记录增量：共享合并/列表、空号呼叫只回填、普通与翻译选择恢复及明确MOCK已完成，详见recent-interaction.json和DIAL_RECENT_VALIDATION.md。生产系统记录与App翻译归档仍未接，不能把交互完成解读为数据能力完成；视觉继续集中后校准。

以上为最初拨号批次边界。后续增量已接T9/号码提示、翻译配置/隔离通话页面和开发者串本地解锁；当前仍待通话历史、跨境/定位、普通地区持久化与真实媒体，详见总验收矩阵。普通电话不进入 App 内 Agent 通话页。
浏览器无法证明 native 电话交接；双端薄适配仍需真机验收。

## 验证

2026-09-17 联系人建议增量：复用现有拨号页，新增列表组件/交互图见component-tree.json、suggestions-interaction.json。姓名首字头像为v65本来就有的文本圆形，不是缺失图片替代；新增资源为空，不使用preview截图。列表新增范围的布局/样式/事件均有静态来源；没有运行态坐标或最终保真评分。Header、数字键盘、底部操作与SVG复用未改。全部新交互绑定真实InkWell/TextButton；候选选择不导航或拨号；状态与数据在controller/domain、页面仅展示。静态优先授权覆盖旧截图门禁。最近通话仍待接入，不因本批T9完成而标记整个拨号模块通过。

纯规则/Controller/MethodChannel 自动测试；国家搜索、键盘、删除、返回、小屏 widget 测试；Web 页面浏览器演练；analyze、全量 tests、Web/Android 构建。真实拨号不在自动化中执行。
