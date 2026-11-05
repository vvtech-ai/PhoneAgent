# Auth 架构检查

输入：本批生成结构与 Flutter lib；版本见 SourceSnapshot，2026-09-16。

- 入口只挂载主题/导航；页面、通用组件、Controller、纯 Dart domain、data 分离。
- UI 不调用 HTTP/存储/设备；Provider 是依赖装配边界，不在 Widget 中创建 Repository。
- 状态单一来源 AuthController；TextEditingController 只维护输入焦点/选区镜像，事件回传 Controller。
- 返回邀请码通过 auth gate + PopScope 回到已保留登录草稿；不是全局 route 字符串覆盖。无多层 overlay/Tab，相关导航场景不适用。
- 异步 generation + mounted 防止退出后旧响应覆盖状态；冷却 Timer 在释放时取消；凭证不输出日志。
- 测试替身仅测试入口注入，普通入口 UnavailableAuthGateway 明确失败。
- 真实控件事件，无透明命中覆盖层、绝对坐标播放器、整页截图背景。Logo 独立资源，样式 token 来自测量。
- `flutter analyze` 和架构测试通过；手写文件均≤500行，用户阈值优先于技能300行默认。

结论：本批结构通过；AuthGateway 成功结果到会话持久化/认证路由的交接尚未实施，不能直接替换网关后宣称完整登录。后续接口批次必须补齐这一交接。
