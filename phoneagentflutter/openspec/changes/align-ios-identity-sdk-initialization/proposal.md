# iOS 认证 SDK 按进程初始化

## Why
Flutter 当前每个新采集会话均调用 `initSDK`；AIAssistant 的单例适配器仅在初始化调用正常返回后设置 prepared。用户批准仅对齐 iOS 初始化频次，要求 UI 交互与既有参数传递处理完全保持。

## What Changes
- iOS 首次显式 prepare 时初始化 SDK，同一进程后续复用初始化状态。
- 每个新采集会话仍独立获取 MetaInfo，请求原初始化接口并传递本次 certifyId。
- 初始化抛异常时不置已初始化标记，沿用原失败出口，允许后续显式重试。
- 补充原生初始化生命周期回归和验证记录。

## Impact
仅 PhoneAgent 的 iOS IdentityCaptureSDK 原生适配与测试、文档；不改 Dart、Android、UI、业务接口、音频配置、线程及供应商文件。复用初始化不代表已证明能解决声音克隆失败。
