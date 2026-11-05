## Why
用户2026-10-09确认执行：设置首页不应有“实时翻译通话”；无有效原生对应流程的独立跳转页也应移除。之前Flutter额外增加首页入口，国内拨号点击模型push配置页，与固定两原生有效流程不同。

## What Changes
- 移除首页国内模型卡片、参数和仅供此入口的位置/路由装配。
- 国内拨号模型入口改为共用模型选择弹层；保留服务端模型目录/选择确认、失败重试和账户生命周期。
- 删除DomesticSettingsRoute和DomesticModelSettingsPage，原音入口保留在设置首页。
- 不改国外模型、可信来电、版本更新、退出、模型协议/配置/电话链路。

## Impact
仅settings与translation presentation导航及直接测试。无平台、依赖、数据迁移或真实外呼。现有pubspec.lock他方改动保留；当前共享分支codex/dev_zys，明确文件提交。
