# 设计

仅调整 CallVoicesPage 的系统音色试听条件：目录 previewAudioUrl 非空，或已有本地样音时可提供试听回调。ApiSystemVoicePreview 已在 URL 非空时直接下载，本次复用此行为，不调用生成接口。

2026-10-16用户授权智能合并远端，以上URL门禁扩展为远端当前规则：有效音色ID即可使用既有ApiSystemVoicePreview；有URL仍直接下载，无URL允许既有动态试听路径。加载/保存/待刷新门禁和试听不切换选择的语义保留；本地两端UI测试同步新规则，集成验证统一记于align-native-orchestration-presentation。

通过 Android/iOS widget 测试覆盖不在本地名单的 lzy、禁用状态和点击不切换音色；运行现有 API 试听测试验证配置 URL 时不生成。执行 flutter analyze 和 openspec validate --all。构建安装及真机听感另验，不覆盖工作区其他改动。
