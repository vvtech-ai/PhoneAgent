## Why

运营需要精确筛选邀请时间、调整 App 通话模型顺序和新用户默认项，并独立维护会员权益介绍。现有列表只有日期、默认项依赖排序、权益介绍由客户端拼接，不能满足本轮运营要求。

## What Changes

- 邀请统计与记录采用北京时间日期时间范围，查询、快捷范围、重置与导出保持一致。
- 新增通话与实时翻译模型展示配置：各自排序与唯一默认一起保存，翻译不分国内外；首页和任务复用通话目录顺序，推荐独立。原分组标题旁提供对应明显入口与弹窗。
- 保留账号已有有效选择，仅无选择或原模型不可用时优先后台默认，再按顺序选可用模型；不改写已打开任务。
- 四档会员支持手填介绍列表、增删排序、逐条常规/放大字号。每月积分仍根据基础与赠送数值生成只读首行，仅字号可调。
- 旧快照兼容；新介绍仅影响展示，不授予权限或改变积分、计费和购买事实。

## Capabilities

### New Capabilities

- `invite-datetime-filter`: 邀请查询与导出的精确时间范围。
- `call-model-presentation`: App 通话模型顺序、默认项及偏好保留。
- `membership-copy-editor`: 手填权益介绍、只读月积分和配套字号。

### Modified Capabilities

无。现有主规格未包含这三个运营配置能力；既有任务编排与会员权限合同继续有效。

## Impact

Java Web/SDK API、公共会员快照；Vue 邀请与模型/会员配置；Flutter 通话目录和会员展示。复用 ai_model、global_config、commerce_config_version.snapshot_json，无新依赖，不部署或写共享业务环境。各仓仅 feature/test_v1.8.0；详细接口和验证见 design.md、tasks.md。
