# OCR组件映射

- OcrAttachmentCard：图片气泡、状态/失败、字段卡、完整文字/展开控件；ImageProvider由调用方提供，不访问网络/设备。
- ConversationTimelineAttachment：UI层锚点插槽，既有普通消息样式不复制。
- OcrPreviewPage：复用ConversationPage/Header/Composer；独立演练路由和选择sheet，六个场景都通过同一状态机，不是六份静态页面。
- OcrController：选择单飞、识别和整理两端口、失败映射、晚到保护；domain模型不依赖Flutter。

没有可编辑字段、号码拨号、确认按钮或伪造生产成功。静态tokens在ocr_tokens.dart；最大新增源码175行，未改变500行项目约束。
