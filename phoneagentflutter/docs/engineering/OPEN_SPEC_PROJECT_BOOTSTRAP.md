# 新项目默认接入 OpenSpec 流程

本文用于本项目接入“验证-实现-归档”的 OpenSpec 流程。

## 目录结构

```text
openspec/
  config.yaml
  schemas/spec-driven-custom/
  specs/
  changes/
  changes/archive/
```

## 基线能力

首个必须存在的 capability 是：

```text
openspec/specs/phone-agent-flutter-ai-development-workflow/spec.md
```

后续拿到需求文档后，按登录/账号、核心业务流程、页面/路由、平台能力、数据存储、构建发布等 capability 拆入 `openspec/specs/<capability>/spec.md`。

## 变更流程

行为变化先创建：

```text
openspec/changes/<change-id>/
  proposal.md
  design.md
  tasks.md
  specs/<capability>/spec.md
```

验收通过后再归档到 `openspec/changes/archive/`，并把最终能力合并回 `openspec/specs/`。
