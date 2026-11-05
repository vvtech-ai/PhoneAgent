# 设计

## 已确认现状与目标
初始排查基线为 test_v1.8.0_fix / 7212eafd，修改前工作树干净。用户随后指定本批改动应放在 feature/test_v1.8.0_zys；以该分支 5d34f57a 为交付基线，在独立工作树移植，保留已有 build-mode、符号和清单核验改动，原分支恢复本批改动。现有脚本先选择本地描述文件，再无签名编译及手动签名，所以工程 Automatically manage signing 不会自动刷新该脚本用到的缓存。此前 prod 无设备选择结果主包及推送扩展为 Store、Live Activity 为 Ad Hoc，说明 get-task-allow=false 不足以区分分发目的。

## 分发类型与设备选择
- Development：get-task-allow=true 且有设备清单；dev/test 沿用此规则。
- Ad Hoc：get-task-allow=false、有设备清单、非 ProvisionsAllDevices；prod 有 --device 为正式环境直装。
- App Store：get-task-allow=false、无 ProvisionedDevices、非 ProvisionsAllDevices；prod 无 --device 为上架。
- Enterprise 或结构不合法的描述文件拒绝，不降级。

先完成所有身份、证书及权限门禁，再按覆盖设备数降序、精确身份优先、CreationDate 降序、路径/证书稳定排序。覆盖数只在相同分发目的且全部授权条件满足时比较，不给任意 profile 放宽权限。缺目标设备时失败。不会自动注册以后新增的设备；每次新增仍须由 Xcode 更新配置，本次验收覆盖全部16台。

## 文件职责与验证
ios_build_config.py 负责选择阶段的类型门禁及排序；test_ios_build_config.py 使用模拟 CMS 输出验证旧13台与新16台、通配扩展、Store/Ad Hoc/Enterprise、缺设备及跨类型拒绝。build-ios-package.py 保留现有入口，仅补 --device 用途说明。现有清单结构、验包 API 和目标设备摘要绑定不改；三个目标及同证书重选均调用同一个选择器，逐一通过相同类型门禁。通用验包继续按已有身份和清单签名事实核对，支持调度器不带设备参数的再次核验。

Xcode 使用既有归档、已有证书和自动签名重新导出以刷新签名资源，不发布、不安装、不拿旧包冒充新交付。核对导出包中主包和两个扩展设备授权、签名及原有权限；实际安装和生产业务配置交付不在本次验证中。
