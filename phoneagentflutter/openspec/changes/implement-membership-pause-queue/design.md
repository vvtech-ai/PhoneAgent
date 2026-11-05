# 设计冻结

## 决策与来源
PDR v1.3 / PAUSE_QUEUE_V1，2026-10-14。引用路径和摘要见 proposal。现有 AGENTS、OpenSpec config、相关旧 commerce change 已核对；导航为 OMS，不作为本系统模块事实。Flutter 基线 cedc850d，Java f2341766，Web a7c9cb3；保留全部历史 change 与语音采集更新。

## 分层与扩展
Java 新 membership-core 负责状态/时间/仓储，SDK 编排支付、SSE共享准入、Web只读投影及渠道事件审计；Flutter domain/data/controller/widgets 分责。Controller/Composable 不直接写状态。不向既有大文件塞入新状态机；今后渠道接适配器、权益排序与时间规则在core集中扩展。T01仅文档和JSON，不影响数据库、日志、提示词、SIP/ASR/TTS引擎。

## 冻结范围
共同 fixture 的字段、null、字符串ID与真实状态展示必须遵守 contracts/README.md。membershipVersion 为业务版本，row_version/时间游标不使普通报价失效；付款成功后锁内按实际权益重判，不能要求重付。日历从初激活原点分别 plusMonths，恢复不重建；每账号唯一ACTIVE、永久发分来源、200边界分批独立提交、统一锁序均依 PDR §2/3。未知渠道结果不能当失败；历史迟到支付进入人工核对，不重建新权益。

## 数据与运行边界
T02 SQL只能隔离 MySQL5.7 演练；开发重置只适用核实UUID及精确库名并已备份/恢复验证。维护/部署、实际支付与退款和双端设备仍待T08b，不在T01声称完成。禁止源码与规格不一致时只在聊天变更契约。

## 验证
openspec validate --all --strict；UTF-8/JSON/null/摘要/相对链接与A01～A28追溯校验。后续测试名称及命令见PDR §8.1，不因冻结规格勾选业务测试。
