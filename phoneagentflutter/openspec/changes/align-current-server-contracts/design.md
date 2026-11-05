# 设计

## 基线与边界
Flutter起点0d0e7480，参考aiassistant_app d183fdf，保持codex/dev_zys本地工作。用户已批准十批计划。登录失效统一清理/跳转/提示暂缓；鉴权仍补齐。UI保留风格，仅数据、门禁、状态改变。

## 结构
服务归属由ServiceRoutes控制，新增统一账户保护策略复用AccountApi刷新及C1，不改401重试终止行为。OCR独立无凭据PUT端口，授权及complete走账户接口；同一附件与提交身份用于重试。邀请来源持久化，不由长度推断。
翻译目录与runtime为data适配/domain模型，Provider账号隔离，国家/模型/节点冻结到本通话；普通ASR/TTS与翻译节点分离。海外既有create-media-ready-merchant-call保留；v70未启用路径不凭接口声明切换。
代办通话明确command/tool/attempt/callId关联，恢复只读；物理结束与agentOutcome分离。字幕按可信segment及快照合并，保留重复发言。

## 验证
每批analyze及定向测试；鉴权跨模块和交付增加集成回归。离线fixture无真实用户数据；平台媒体和实际服务保持待验。每个源码微批最多3文件，机械格式化单列。下载等检查项仅凭证据修改。

## 精确模型身份
Android AssistantCallRuntimeControllers.selectedTranslationModelCode优先本地模型ID，再选匹配协议的国家绑定模型，再取首个可支持模型。Flutter新增国内/海外模型ID偏好及纯domain选择策略，Provider隔离账号目录与地区。设置接口保留独立兼容路径并补region，不作为正式拨号gate。国内plan同时冻结modelId与协议provider；runtime与计费传精确modelId。海外保持旧create协议provider字段，补充modelId，节点按精确模型验证。UI保留样式、明确加载失败重试。
