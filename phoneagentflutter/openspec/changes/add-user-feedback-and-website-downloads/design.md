# 设计

## 23829 提测修复（2026-10-27 用户批准）

Picker 仍在处理图片前整批拒绝超选，提示本次选择超限和实际剩余数量，不自动截取也不清除已有图片。离页通过现有 `core/design/native_business_dialog.dart` 的确认组件承载原文与动作，参考 settings 的 logout_dialog；不新增页面自绘弹层，不改变草稿、提交忙碌和重复弹窗保护。Android/iOS 共用同一 Widget。App 版本保持 1.0.53（46）。

批准依据：工作区 docs/1870_1872_反馈与官网下载_PDR.md v1，接口合同 story-1870-1872-contract.md v1。

领域模型与校验独立；提交控制器持有页内草稿、处理/上传状态、不可变请求和日志快照。数据层复用 AccountApi、image_picker、AppLogRepository prepare/ack，不经过旧日志 upload。图片适配器验证原图 10MiB，最终 JPEG/PNG/WebP 2MiB；设备可解码其他格式转换 JPEG。预览和 multipart 共用最终 bytes。

失败保留请求、表单和日志 snapshot；未编辑重试同 UUID 和相同有序附件，编辑后新 UUID。成功后才 ack 原快照，ack 失败只重试清理。Provider 绑定 loginEpoch，异步上传前重验原账号，账号切换丢弃旧页草稿，迟到结果不写新页。

UI 单卡片字段顺序和文案来自 5b644bf8:design/demos/user-feedback，日志 16px 方框与 8px 间距。关于页去掉日志行，其余诊断基础设施保留。只触及必要入口，不向已有大文件增加业务流程。

用户后续明确日志勾选状态也须使用App默认按钮蓝色：选中背景及边框复用ShellTokens.accent（#0A84FF），保留16px、8px间距、未选中灰边白底及整行点击；不再沿用Demo紫色。此处为用户明确视觉覆盖，不修改默认不勾选或日志提交规则。

## 双端设备环境（用户追加）

Android/iOS 共用纯 DeviceEnvironment 模型和摘要格式化器，独立平台适配通过 app_info/readEnvironment 取得公开技术字段；readC1 的原始字段及签名身份保持不变，避免新增诊断字段进入严格 C1 白名单。Android 增加 Build.DEVICE，iOS 使用 uname 的 machine（例如 iPhone16,1）；不猜营销机型，不读取序列号或用户设备名称。iOS 相册权限用途包含反馈截图，版本按用户最新指定更新为 1.0.53+46；Android/iOS 主包及扩展继承共享版本源，Android 现有脚本的 build-name 同步为 1.0.53，构建号参数使用 46。

日志 prepare 时捕获不可变设备快照，正式 ZIP 同时包含 diagnostics.jsonl 和 device-environment.json。普通上传及反馈优先从同一快照生成不超过 512 UTF-16 单元的 deviceInfo。账号在异步读取前后重新校验。平台读取失败不丢日志，ZIP 写 available=false；重试可补读用于 deviceInfo，首次取得后固定，ZIP 保持原字节及校验和，不追写。读取仍失败则带日志上传失败并保留重试，不填假版本。无日志反馈允许省略可选设备信息。

职责拆分为 core 不可变模型、data 原生适配、domain 有界格式化、provider 接线；今后新增技术字段通过模型/适配扩展，不把采集放进反馈 UI。服务端仍保存原 ZIP，现有 device_info(512) 可容纳摘要，本批无需数据库迁移。
