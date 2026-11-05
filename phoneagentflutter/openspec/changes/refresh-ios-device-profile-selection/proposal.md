# 修复 iOS 新增设备的描述文件选择

## Why
用户要求开发包、测试包和正式环境直装包覆盖已登记的全部测试机。当前缓存有13台设备的旧配置；选择器按路径排序且只检查 get-task-allow，正式包可能混选 App Store 和 Ad Hoc。Xcode 已刷新正式 Ad Hoc 为16台，开发配置刷新中。

## What Changes
- dev/test 固定 Development；prod 指定设备时选择 Ad Hoc，未指定设备时选择 App Store。
- 保留团队、身份、证书、有效期、目标设备、主包通讯通知和 APNs 校验；合格配置按设备覆盖数量、新旧和精确身份稳定选择。
- 主包及两个扩展使用同一分发类型；本次逐项核对实际配置覆盖全部16台及新增三台。

## Impact
PhoneAgent 仓库，状态 owner 为 iOS 签名工具；入口为 build-ios-package.py 和最终包身份核验。身份为 Team、Bundle ID、证书、profile 类型及设备授权，不涉及业务接口。保留 dev/test development APNs、prod production APNs、两个扩展、白名单清单及 cloud-pro 配置门禁。回归 IOS-PROFILE-01～04；不影响任务编排回放，不安装旧归档、不变更版本。按用户随后指定，将本批改动提交到 feature/test_v1.8.0_zys，恢复原分支本批改动；本次不推送。
