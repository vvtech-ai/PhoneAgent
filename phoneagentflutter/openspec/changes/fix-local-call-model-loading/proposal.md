# 修复本地真机模型加载

## Why
本地开发包的会员目录已读取真实发布商品，但通话模型列表仍显示加载失败。必须以真实异常和接口契约证据定位，不能把缺少日志推断为后端无数据。

## What Changes
- 通过不包含账号、凭据或响应正文的临时调试元数据定位失败层。
- 根因是 Java 目录对未接入 INDEXTTS_QWEN 调用执行枚举校验，整个目录返回 AC0001；Java 按实现可用性修复，Flutter 无需业务改动。
- 交付前移除临时采集源码，不把调试入口交付给用户。

## Impact
- Java RealtimeModelSettingsService / RealtimeCallModelSelection 已修复（主任务提交 6659d4e6）；Flutter 保留既有模型 DTO 与业务代码，仅移除临时采集。
- 无数据库迁移、供应商调用或支付交易。
