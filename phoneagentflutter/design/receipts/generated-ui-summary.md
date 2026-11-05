# 回执共享组件：结构/交互验收批次

输入：SourceSnapshot/DesignTree/NormalizedDesignTree、component-tree、AssetManifest、三个交互图和InteractionMap。固定设计0cd58de、v65 4c781e3；2026-09-17用户批准静态先行，未以运行态坐标缺失阻断。以下同时作为本小批normalize/components/assets/interaction/architecture/review报告索引。

## 来源与生成

- 单路使用pv-summary/transcript静态参数；批量采用当前v65有效组件，不迁移旧静态餐厅弹窗和metadata表。
- Single 280、Batch 308、自适应缩小；圆角16；文字14/12/11；展开按钮最小44；进度7。具体样式见component-tree和ReceiptTokens。
- 新增1 tokens、3 widget文件、1纯合成fixture、1隔离页面；既有消息按类型分派，开发者入口push，关闭/系统返回pop；无新增main.dart逻辑、JSON运行时renderer、透明热区或截图背景。
- 语义组件覆盖：当前选中单路/批量结构均落到具名Widget；全项目页面/视觉节点覆盖率不在此小批统计。无新增位图/字体，沿用应用字体和周边对话SVG；资源清单为空有明确来源理由，无pending资源。
- SafeArea由页面提供；无设计系统栏/键盘；时间线填满可用空间、滚动，composer沿用底部布局。单项状态由本Widget持有，数据由既有模型提供，不访问网络或存储。手写新增文件均低于500行。

## 参数校准待办（不宣称高保真）

| 组件 | 已落实 | 尚未测量/差异 |
| --- | --- | --- |
| 单路转写/结果 | 宽度、圆角、语义渐变、角色、字段、计费 | 场景标题、精确行高/边框/对齐和像素误差 |
| 批量列表/按钮 | 宽度、逐项底色、进度、44高度、展开状态 | shell共用16×14内边距而非源14×12、header分割/进度蓝色细差 |
| Header/Input/底部控件 | 复用已有ConversationPage | 本批不重新测量，不声称整页一致 |
| 图片/头像/FAB/Dialog | 本批无新增 | 不适用 |

独立展开、重排不串项、身份/状态/转写更新折叠、终态计数、缺失数据不造费用、三宽度大字体及连续返回均有测试。浏览器演练和命令证据见../../docs/engineering/RECEIPT_UI_VALIDATION.md。允许继续交互实现；禁止把此批当录音、真实外呼或最终视觉验收通过。
