# 商业化与任务入口修复（2026-10-15）

对应 OpenSpec `repair-commerce-and-task-entry-experience`。用户已批准六项实现，并明确由用户自行构建发布 Java/Web；本次仅交付测试环境签名 APK，不部署、不安装手机、不调用真实短信/支付/人脸/外呼。

## 改动
- 订单列总宽度由缩放列宽加固定20像素内边距组成；85%字号旧实现精确RED为3像素溢出，修复后0.85/1/1.5/2倍通过。
- 发票详情移除OFD/PDF/XML保存打开和对应Flutter文件下载/平台适配孤立链路；申请表邮箱、已有状态和查询重试保留，详情无新增邮箱入口。
- 克隆权益按SDK独立字段判断，无权取消或去升级现有会员页，未知可重试；详细证据见CLONE_ENTITLEMENT_ENTRY_20261015.md。
- Android TaskLocationPermission独立管理用户首次提交订餐/附近任务的定位预检，已有授权不弹，拒绝记录与权限工具共享，返回同任务保留，登录变化重建，用户明确肯定授权可重新申请。否定定位表达不触发；固定联系人、空提交、工具续跑不触发预检。权限完成后先获取新鲜上下文再发送同一原command一次。iOS保留原任务权限事件流程。
- Java积分包排序、历史快照流水与克隆目录投影，Web拖动排序由对应仓库同名change承接。

## 验证
- 初始订单/发票RED：旧表格85%字体3.0px溢出，已出票仍有三个文件按钮；修复后67项定向通过。
- 定位单元初始RED 4项；组合回归补获首次拒绝后工具二次弹窗RED（原调用2次，预期1次），共享拒绝记录后GREEN。最终定位9项通过，覆盖并发、拒绝、明确肯定/否定、账号切换、路由重入及取消。
- 受影响Commerce/VoiceClone/Identity/Auth/配置及对话模块1218项通过；首次批量命令另含一个不存在的shell路径导致命令exit1，已按git ls-files更正，实际test/shell_clone_workbench_test.dart单独5项通过。无测试业务失败未处理，不重复已通过集合。
- 最终flutter analyze --no-pub：No issues found。首轮6项括号风格info已修复，无放宽lint。
- OpenSpec全量154通过/0失败；独立复核修复跨工具拒绝、Provider生命周期、否定表达及preview fixture契约问题；相应组合回归通过。
- 375/390/430宽、1/2倍字号48项视觉fixture通过并输出截图，已目视核查订单与发票申请及Web移动排序。截图为合成数据，不代替真机。
- 真实Dart product AOT配置探针通过：test环境和三个HTTPS路由均可用；Auth受影响集合包含真实网关分派单元测试，不发送短信。

## 打包与依赖
计划1.0.51+2026101507，test Release、ARM64、com.vvtech.aiassistant.test，原登记证书MD5 ebd4c931de412bf5d9c3716815389097；遵循scripts/build-task-test-apk.ps1参数校验与Release生成。最终产物验证见工作区deliveries/commerce-entry-repair-20261015。

用户自行发布的SDK必须包含cloneEntitled/entitlementReason，旧接口缺字段会安全提示读取失败，不推断付费账号权益；流水与积分包发布排序也需SDK更新。未修改数据库结构或历史账务，未执行真实MySQL新增展示SQL联调；支付、人脸、真机任务授权仍待运行验收。PMReport registry未登记三个实际独立仓库名，本轮不向旧aiassistant项目猜测上报。


## 最终产物

Phone_Agent_TEST_1.0.51_2026101507_test_20261015_172224.apk，78909028字节，SHA256 aa1609c10660d4b4cc641546fe0341965b15dbdd80116edd0c17d27f328b5d1a。Release构建3分57秒成功；验签/包名/版本/ARM64/AOT/测试地址/11个保护库通过，AOT包含新权益提示且不含保存并打开。未安装手机。实际源码6b3d6cf3；后续仅本交付记录与任务勾选更新，不改变构建源码。Java/Web由用户自行构建发布，源提交及patch见deliveries/commerce-entry-repair-20261015/README.md。
