# 身份页面架构检查

输入：本目录设计产物 + identity feature；固定版本见 SourceSnapshot。

- domain：资料状态/草稿/规则/端口，纯 Dart。
- data：AccountApi DTO映射、POST/PATCH边界，不含页面文案。
- controller：加载/编辑/保存/删除单一状态，异步互斥/晚到隔离。
- app providers：账号依赖组装，页面无API/存储访问。
- route：Navigator与确认弹窗，成功删除失效模型缓存；page/widgets为真实控件。
- 新组件皆低于500行，无通用JSON渲染器、全屏图片UI或跨模块资源复用伪装。

后续跨模块协调未完成：首次身份引导与删除跳过标记、认证录音清理、删除期间离页后的模型刷新协调，需要同 SDK/全局身份上下文一起验收。不在本批声称已完成。

允许继续业务迭代；设备验收门禁未通过，不允许归档/整模块验收。
