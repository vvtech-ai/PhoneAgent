# Tasks

- [x] 增加通用业务与积分 SSE 失败码的安全提示。
- [x] 定向验证 App 的业务、积分、系统及未知错误展示边界。
- [x] 保持现有事件解码；系统诊断由 SSE 后台通过已支持的文本事件控制。
- [x] 运行 OpenSpec、Flutter 分析与相关测试；真实 test 联调另验。

验证记录（2026-10-15）：撤回 App 调试事件接线后的最终状态已用 Flutter 3.32 相关 29 项定向测试、`flutter analyze --no-pub` 和本 change 严格校验复核，均通过。全仓 `openspec validate --all` 先前为 151 通过、3 项其他既有 change 校验失败；本轮未重跑全仓。未部署或真机验收。
