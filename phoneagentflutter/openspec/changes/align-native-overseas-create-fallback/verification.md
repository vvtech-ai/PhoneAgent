
## 2026-10-12 海外创建兼容重试对齐aiassistant_app
- 用户明确要求处理逻辑对齐且UI不变；change align-native-overseas-create-fallback覆盖此前仅UNKNOWN_FIELD/capabilities提示才重试的限制。首次HTTP拒绝或网络I/O失败移除capabilities重试一次（含原生IOException网络语义），其余body/账号header保持；第二次失败上抛，不循环。成功响应解析失败不重建，已有会话清理保留，merchant和hangup不进入该重试。诊断保留。
- 产品源码仅http_translation_backend_repository.dart 1文件微批，测试backend/legacy 2文件独立微批；format机械批，源码220行以内，无500行例外。未修改UI、布局、交互或提示文案；工作区其他修改保留，不提交推送。
- backend/legacy/rejection诊断/coordinator/controller/runtime/provider/session pages及overseas诊断定向75项通过，analyze无问题，OpenSpec100项及diff检查通过；非全量回归。覆盖普通400/500/403/网络超时一次兼容、第二次失败不产生第三次、请求仅移除能力字段、成功响应校验失败清理及页面调用流程。
- 未构建安装、未发送真实创建或外呼请求；服务是否接受兼容请求仍需新包真机验收，不归档。
