
## 2026-10-12 海外服务用户标识对齐原生
- 用户确认计划后执行；change align-native-overseas-service-identity。海外HTTP适配层create/merchant/hangup及兼容重试/异常清理统一x-user-id mobile-app-user；内部request.userId和runtime/recorder/归档仍真实账号，国内接口不改。诊断记录固定NATIVE_SERVICE_USER来源类别，不记录账号或凭证，UI/布局/文案未改。
- 产品源码backend+诊断白名单2文件微批，backend/legacy测试2文件独立微批，format机械批；backend232行，无500行例外，保留其他工作区修改，不提交推送。
- backend/legacy/rejection/runtime/provider/controller/pages/archive/海外诊断/app_logs定向155项通过，analyze无问题、OpenSpec101项与diff校验通过；非全量回归。验证三个操作及清理/兼容header、真实账号快照和记录、登录失效门禁及页面调用流程。
- 未构建安装、未实际外呼。此差异尚未证实为400根因，需iPhone新包复现确认，待验不归档。
