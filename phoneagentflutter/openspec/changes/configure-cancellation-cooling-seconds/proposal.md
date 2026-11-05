# 注销冷静期按秒配置与时长展示

2026-10-28用户批准执行本方案。当前SDK三处Duration.ofDays(15)，Flutter最终确认写死15天，不能用于短时测试。新增Nacos服务配置cooling-period-seconds（默认1296000），统一使用确认流程快照；仅新增现有响应字段，不增加客户端配置权限或新接口。

影响仓库PhoneAgent_server的SDK配置/DTO/Service/Repository/迁移与模板，以及PhoneAgent的DTO解析/领域格式化/最终确认文案。SDK是期限owner，确认ID/短信/VERIFIED/operation仍保持既有账号绑定。保留双确认、自动验证码、主线程当前通话处理、协议固定地址/1.0、逻辑删除、原申请截止和16/17天恢复清理窗口；不修改AGENTS共享规则或历史已受理记录。回放DEL-02-01/05、DEL-03、DEL-05-01/02/05及对应源码连续测试。

源码基线：Flutter3402c958ade1bd41002bb7c98c74be5f75dd4b74，SDK e5b7c09f6aea4ecc66a1587c27b059f9aa2d1843；均feature/test_v1.8.0_zys。实施期间检测到主线程通话处理的并行未提交改动，保持原样，不纳入本次改动归属。安装包未读取，本批不打包/安装。仅修改源码、模板、迁移及本地验证，不操作Nacos、共享数据库、部署、真实短信或账号。
