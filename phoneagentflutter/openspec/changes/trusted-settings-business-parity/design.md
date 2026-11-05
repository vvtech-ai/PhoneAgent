## 固定基线与行为矩阵
Android 0f8879e4baf1d56fe6d7f8f356101fdf61d602ed，iOS bb9ff34966f40a3c2794a9a8b8e935669a9faa12；不跟随参考工作树新HEAD。
| 环节 | iOS参考与目标 | Android参考与目标 |
|---|---|---|
| 初始化 | 点击调用应用服务幂等初始化 | Application启动初始化，入口只幂等确认 |
| 账号 | 当前登录账号/手机号及异步归属 | 同步当前有效账号，Flutter桥结果可等待，不遗失失败 |
| SIM | SDK手机号码初始化 | 有卡同步实际号码，缺失时登录号码回退；无卡跳过仍可进入SDK |
| 首次 | 本地按账号，展示前标记 | 全局本地已看引导，SDK调用前标记 |
| 首次页面 | 全屏说明→开始→SDK→整体返回设置 | SDK openIncallUi |
| 后续 | 直接SDK全屏设置 | SettingActivity，失败openIncallUi |
| 授权 | 与打开独立刷新 | 不将点击/本地guide当真实证书授权 |
| 失败 | 原设置页反馈，SDK结果/状态刷新分离 | 原页明确阶段和错误码，不伪报状态读取失败 |

## 必要适配差异
Flutter平台通道必须确认账号/环境/代次，账户同步串行并使过期请求失效；不绕过账号校验。参考Android点击写authorized字段只参与引导事实，Flutter不输出SDK授权true。旧账号SIM ownership journal未知/清理失败阻断；普通无卡、无权限、无号码产生空计划可通过，不等同清理失败。Android本工程旧账号级引导true迁到全局guide，不跨读取旧App私有prefs，OTA迁移独立验收。iOS新账号级guide兼容当前工程旧环境+账号key。SDK页面仍由原生SDK承载，Flutter说明保留至SDK完成；UIKit原项目push与Flutter/SDK modal组合的动画需真机配对，不伪称像素一致。

## 同步与诊断
应用级同步协调器拥有目标owner/环境及版本，串行更新、同目标去重、失败下一次可重试，旧成功不可使新目标就绪。入口确认后再prepare，UI可见性/owner在每次await后复核。诊断使用枚举stage/environment/错误白名单，不存账号、手机号、surfaceToken、密钥、exception text。记录同步/prepare/open/refresh/guide/release耗时和结果，通过现有DiagnosticEvent导出与roundtrip。未知原生错误映射固定unknown，不打印任意errorCode。

## 验证与边界
源码微批<=3文件，纯策略/协调器单测、可信/设置/诊断定向，analyze/OpenSpec，平台改动双端构建。真实首次/后续/取消/开始/返回/权限拒绝/双卡/重启/换账号配对清单待设备与账号条件，实际执行与编译分开。对账号协调器改变涉及调用方的测试拓展，非全项目鉴权改造，不强制重跑历史其他模块失败的全量。

## Android运行时依赖修复
参考runtime/sdk.jar含613个class，SHA256 d76d1b06d1e186bd218506bb1b452a63876a7888c8bb851669d21803deb6873e。现有本地AAR无重复class，漏打包导致初始化引用的ChakenNetworkConfig缺少定义。复制到libs/trusted_caller/runtime/sdk.jar，通过implementation打包；APK校验只认class_defs，不以DEX字符串引用当定义。初始化只记录固定错误类别，不输出异常message/stack或配置。真实设备尚待验。
