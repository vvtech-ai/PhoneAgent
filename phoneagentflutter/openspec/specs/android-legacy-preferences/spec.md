# android-legacy-preferences

## Purpose

定义Android同生产包升级时有效翻译/原音及身份初始化跳过偏好的导入边界，真实验收状态以active change为准。

## Requirements

### Requirement: 仅同生产Android作用域可读取白名单旧偏好
系统 MUST 同时校验Android非Web、精确prod API及实际生产包名，仅读取固定v65有效偏好；MUST NOT 接受任意文件/key或返回账号、号码、权限授予状态。

#### Scenario: 不可迁移平台与环境
- **WHEN** Web、iOS、非prod接口或非生产包尝试恢复
- **THEN** 不导入旧偏好，保持既有Flutter存储行为

### Requirement: 新偏好优先且导入与写入串行
系统 MUST 仅在新安全key不存在时映射旧值并先持久化再返回，读写按同key跨实例串行；MUST NOT 用旧源覆盖新数据或掩盖新数据读取/解析失败。

#### Scenario: 失败与并发
- **WHEN** 目标写失败、旧字段类型错误或导入期间发生新设置写入
- **THEN** 失败明确可重试，保留旧文件；并发最终以较后新写入为准，新key成功后不重复读取旧源

### Requirement: 映射只保留本期有效翻译与原音配置
系统 MUST 保留翻译开关、提示、七语言、双模式地区、海外模型/节点/强制偏好和原音开关/比例/音量；缺失或未知枚举按既有有效默认值，MUST NOT 引入国内SIP或将区号/历史权限标志当可信位置或权限。

#### Scenario: 旧值导入
- **WHEN** 旧设置存在且新key不存在
- **THEN** 中文语言名映射为现有语言码，海外枚举和节点规范化，原音按v65范围处理，旧源不写不删

### Requirement: 保留设备级身份初始化跳过选择
系统 MUST 在相同生产双门禁下仅导入v65设备级identity_initialization_skipped布尔值，不读取身份内容、不改变初始化门禁或页面步骤。新key存在时MUST保留现有解释规则；新key缺失且旧值存在时先持久化，缺失不写默认，读写按同key跨实例串行。

#### Scenario: 导入期间用户跳过
- **WHEN** 旧值读取未结束且用户执行markSkipped
- **THEN** 当前实例立即保持跳过，串行完成后持久值为true；旧false不得覆盖较后新写入

#### Scenario: 导入失败或旧源缺失
- **WHEN** 旧值类型错误、源读取或目标写入失败
- **THEN** 明确失败且可重试，不写删旧源、不发布未持久化的旧true；源缺失仍返回原默认

### Requirement: 保留定位确认国家缓存而不伪造实时定位
系统 MUST 仅从v65 translation_region_state导入trusted_country_iso及trusted_country_sampled_at_ms，复用生产双门禁和新值优先串行规则；MUST 保留原采样时间并标记缓存，MUST NOT 读取坐标、用拨号国家替代定位、伪造权限或刷新采样时间。

#### Scenario: 首次读取有效旧定位缓存
- **WHEN** 新位置安全key不存在且旧国家与采样时间有效
- **THEN** 规范化国家ISO，先保存至新key再返回，由现有位置控制器显示缓存；无需定位权限或网络请求

#### Scenario: 缺失错误及并发更新
- **WHEN** 旧源缺失、格式错误、目标写失败或同时有新定位写入
- **THEN** 缺失不写默认，错误保持可重试且不掩盖损坏的新key；同key跨实例串行，较后新定位写入最终保留，不改删旧源
