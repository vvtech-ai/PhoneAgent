# 添加内容与文档导入交付记录

## 实现边界

遵循用户“静态 HTML/CSS 与现有组件先完成交互”授权。Design2App 的来源提取、组件映射与交互记录用于限制范围，不以缺少运行态设计截图阻塞开发，也不声称视觉零差异。

共享 UI：AttachmentMenu、DocumentImportSheet。独立 DocumentImportController 只编排选择和解析端口，ConversationController 只增加文档轮次入口。file_selector 官方跨平台适配不复制旧 Android 架构。手写源码不超过项目500行约束。

## 交互验收

- 自动：取消、无效扩展名、5MiB边界、实际字节超限、多文件顺序、部分失败、关闭晚到、重复选择、账号切换、multipart契约、文档命令和320/390/430竖屏。
- Web实测：从首页会议邀请进入添加内容、MOCK正常多文件、部分失败重选；无真实文件/联系人上传。
- 构建：Web、Android Debug、Mac iOS Debug无签名通过；不等于已安装或原生选择器验收。

## 明确保留的差异

- 增加复用进度sheet，用户从菜单选择文档后还需点击“选择文件”，便于Web维持浏览器手势；不是v65已有确认步骤，待统一交互/视觉校准评估收敛。
- HTML只有图片入口；文档入口按v65补齐。图片入口明确提示OCR未接入，不伪装成功。
- 卡片边距、handle、背景色、内联解析卡/文档消息卡未完成视觉校准。消息只显示安全摘要，持久ledger暂显示“已上传文档”。
- Agent主动索要文档是另一个工具流程，其取消回传、类型和限制不能套用此主动上传流程。

详细验证和人工操作见 `docs/engineering/DOCUMENT_IMPORT_VALIDATION.md`。
