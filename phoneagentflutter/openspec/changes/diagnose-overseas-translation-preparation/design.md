## 设计
使用账号隔离journal和固定白名单translation字段。coordinator记录阶段及异常发生阶段，媒体候选失败独立记录；语言和后端HTTP记录阶段/status。工厂传递sink。不得记录请求体、号码、userId、URL、token、原始异常或服务端消息；诊断失败隔离。源码每微批最多3文件，测试独立，均小于500行。
## 验证
海外coordinator/controller/backend/catalog/runtime、app_logs定向测试，analyze及OpenSpec；不实际外呼，不安装。

2026-10-12复现HTTP400补充：独立诊断映射器仅输出固定码及整数标记；检查顶层/嵌套错误对象，消息只用于识别固定字段名，不保存文本。记录capabilities是否存在及模型类别，不记录号码、账号、语言值或响应原文。保持业务异常与重试不变。
