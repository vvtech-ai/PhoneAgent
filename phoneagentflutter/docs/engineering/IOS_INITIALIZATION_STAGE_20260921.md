# iOS 两步初始化独立验证

基点6c30648，加本批独立initialization测试分组。正式lib和平台实现未改。本阶段只验证「身份信息→通话模型→首页」，不设置翻译模型。

## Preconditions

- iPhone8/iOS16.7.16，Flutter3.32.0/Xcode15.2；复用现有已解锁screen与工具链环境，不要求重新登录Apple ID。
- 同一正式AuthRoute/InitializationHost，身份、通话模型、跳过和登录仓库采用明确MOCK内存端口；API地址为空，安全存储和系统拨号通道禁止调用。
- Android用户确认手动恢复尚未执行，本阶段不安装Android、不绕过安装限制、不发短信。

## Build / Install

单独构建integration_test/initialization_stage_test.dart，保留原普通二进制；在现有screen中签名、安装与启动，不卸载。STAGE_GROUP=initialization使用现有VM附加和keep-app-running，结果独立存放，不覆盖历史46图。

结束后重新构建当前lib/main.dart测试环境普通包，严格检查签名、安装启动并截图确认普通入口。测试成功和普通包恢复分别取证。

## User Actions / 自动路径

| 检查点 | 自动操作及断言 |
|---|---|
| 47 | 填写合成姓名→模型→返回，姓名保留 |
| 48 | 再进入通话模型，选择Seeduplex；第二步显示完成而非下一步 |
| 49 | 完成直接进入首页，模型仅保存一次；重查内存门禁仍为首页 |
| 50 | 新的空身份场景→跳过→模型→返回，仍可继续 |
| 51 | 再次跳过→选择Seeduplex |
| 52 | 完成直接到首页，持久跳过端口模拟写一次、模型保存一次 |

两条路径均检查翻译Provider未创建、翻译偏好不变、短信和登录提交0次。本阶段主动收起键盘，不替代独立keyboard阶段，不证明IME组合输入或设备冷启动存储。

## Expected Logs

驱动输出All tests passed和Leaving the application running；result.json包含completed=true、六个completedSteps、forbiddenNativeCalls=0及六张有效PNG。普通入口恢复须独立具备构建成功、codesign严格校验和登录页截图。

## Forbidden Logs

禁止forbidden_in_stage、布局溢出、未处理Flutter异常、测试中失联或崩溃、真实SMS/身份/翻译/存储/拨号、安装失败后卸载重试。不以PNG格式有效代替逐图查看。

## Pass Criteria

本机13项预检通过：375×667/393×820双平台样式四项、320/430宽填写与跳过四项、安全附加驱动五项；analyze无问题。不跑全量回归，仅本阶段六个截图检查点。

## Failure Follow-up

失败保留具体步骤和日志，仅修正已定位问题后重跑本分组；不放宽业务断言。Android、真实身份/跳过存储冷启动、认证SDK和统一视觉精校继续独立验收，不因本阶段成功勾选整体迁移。

## 实际设备结果

2026-09-21 11:10 CST，构建85.3秒、安装启动46.3秒；设备测试约9秒通过。附加驱动成功并保留App。[结果JSON](../../.local/initialization-stage/ios/result.json)为completed=true、forbiddenNativeCalls=0，六图均750×1334。

- [47返回保留姓名](../../.local/initialization-stage/ios/47-initialization-draft-back.png)、[50跳过后返回](../../.local/initialization-stage/ios/50-initialization-skip-back.png)：姓名与空姓名两态正确，跳过、表单和底部按钮可见。
- [48选择通话模型](../../.local/initialization-stage/ios/48-initialization-model.png)、[51跳过路径选择模型](../../.local/initialization-stage/ios/51-initialization-skip-model.png)：Seeduplex选中，第二步底部为完成，无第三步。
- [49填写完成首页](../../.local/initialization-stage/ios/49-initialization-home.png)、[52跳过完成首页](../../.local/initialization-stage/ios/52-initialization-skip-home.png)：首页模型显示Seeduplex。滚动内容可延伸至浮动导航后方，截图不证明所有首页卡片均无需滚动；本阶段不做首页全交互或像素验收。
- 六图已逐张打开，未发现本阶段表单/完成按钮截断；黄色MOCK条占用屏幕高度，不等于正式视觉基准。13项相关预检、analyze及30项OpenSpec通过，没有全量回归。
- 首次screen以相对路径启动脚本未进入构建；确认无日志/无对应任务后改为绝对脚本路径。未重复已运行构建，没有修改系统Xcode或钥匙串。

## 普通入口恢复

6c30648普通lib/main.dart测试环境包已恢复：构建26.3秒、安装启动45.8秒，codesign --verify --deep --strict通过，普通runner发布新VM服务。[USB整屏截图](../../.local/initialization-stage/normal-restored.png)已打开：普通登录页，无MOCK栏；iOS此前未登录，本轮不声称登录恢复，也未发验证码。现有解锁screen保留，普通窗口为initialization-normal-run。
