## ADDED Requirements
### Requirement: Android可信SDK页面必须遵循参考生命周期
宿主 SHALL 首次调用openIncallUi，后续启动SettingActivity并失败回退；SHALL NOT 自定义25秒启动等待、防重复SDK启动或因账号/引擎释放finish厂商Activity。MethodChannel SHALL 只回传启动调用结果。
#### Scenario: SDK页面存续时账号变化
- **WHEN** 账号变更或Flutter桥接释放
- **THEN** 不强制关闭SDK页面，不撤销系统角色或SDK开关
### Requirement: Android账号变更必须保留参考SIM存储语义
宿主 SHALL 对有效登录号码按参考规则同步；退出或引擎替换 SHALL NOT 清空SDK SIM号码，SHALL NOT 读取旧归属journal触发清理。
#### Scenario: 退出或无卡
- **WHEN** 用户退出或没有检测到SIM
- **THEN** 不写空号码、不清旧槽位数据
### Requirement: AndroidSIM读取及写入必须遵循参考顺序
宿主 SHALL 先尝试SDK槽位/号码；订阅API在电话状态或号码权限任一具备时尝试；SDK local号码仅null时回退SDK sim接口，再按参考读取订阅号码。单卡空号码回退登录号，双卡仅优先槽1否则最后槽回退。写入 SHALL 先尝试两参数SPUtil.set，否则SPUtil.put(key,number)。
#### Scenario: SDK返回空字符串
- **WHEN** local接口返回非null空字符串
- **THEN** 不调用SDK sim接口，继续订阅号码回退
