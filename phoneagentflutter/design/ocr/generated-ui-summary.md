# 图片识别交互实现

输入：0cd58de静态HTML/CSS/图片和4c781e3 v65 OCR组件/协调器；Flutter单一共享目标，现有Android/iOS宿主不变。用户已批准先交互后视觉，不阻塞于运行态设计测量。

实现入口OcrPreviewPage、1组结果Card、1个共享时间线插槽、独立controller/domain与MOCK端口。关键可操作控件均映射真实事件：进入、选场景、取消、展开/收起、文字发送、退出。图中正文/字段只读。复用现有Header/Composer/MessageTile，未复制业务根页面。

|组件|参数来源/覆盖|校准状态|
|---|---|---|
|图片气泡|v65宽210/padding8/圆角18/图4:3|静态实现，未像素对照|
|缩略图|CSS60×60/圆角14/cover|资源与裁剪接入|
|字段结果卡|CSS max286/padding12/radius18/border/shadow|已消费静态参数|
|字段行|CSS padding8/10/gap10/label54/11/13字号|长字段窄屏自动回归|
|长文字|v65 50字符截断/展开收起、CSS12号字|Widget交互回归|
|统一页|复用共享Header/Composer与SafeArea|不重绘系统栏|

非预览资源2张，引用同一源图作主图/缩略图；没有资源fallback、preview切片或整页背景。系统statusBar/homeIndicator/navigation/keyboard排除，底部沿实际高度锚定。route节点4、状态9、交互组7；数值为本批模块范围，不代表全项目已验收。

已知差异：MOCK场景选择器不是系统相册；标题banner仅演练；字体/阴影/像素误差未测量。正式recognizer/cloud/ledger/context未接线。测试和集中人工步骤见OCR_VALIDATION.md；视觉覆盖率与总体评分不冒报通过。
