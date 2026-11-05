# 任务
- [x] 读取工程基线及关联变更，核对旧三份凭据一致，发现 cloud-pro 仍为 test。
- [x] 创建并校验本变更规格（全量199项通过）。
- [x] 私有配置迁移、Gradle 注入、唯一 Kotlin 读取器及环境门禁。
- [x] 同步脚本/旧工具，增加合成配置与原生定向回归。
- [x] 运行 OpenSpec、Python、Flutter、原生单测及 Android 编译，检查敏感信息和 iOS 边界。
- [x] 更新任务与研发记录，交付差异及未验证项。
- [ ] 用户验收；生产配置、Windows运行和真实设备验收独立待验，不归档。

## Git同步授权
- 用户于本次后续消息明确要求Git提交并推送远程，覆盖实施阶段不提交推送的边界。仅提交本变更的代码、脱敏示例和研发记录，真实cloud配置继续忽略；目标为已核对的origin/codex/dev，普通推送，不归档或扩大运行验收声明。

## 实施进度
- 旧三份私有Kotlin凭据核对一致后，将两个可信字段补入dev/test/pro的原有JSON，保留全部原字段，权限600，确认Git忽略；再删除旧三份源码。iOS私有文件摘要已记录到即时工具输出供结束时核对，不新建报告。
- 生成器Android-only仅校验，不访问原生Git、不生成任何源码；iOS生成格式及固定参考不变，旧私有清单保留。
- 首轮Python旧工具7项、入口8项、生产Gradle脚本合成回归6项通过，Flutter analyze无问题。入口补充JSON对象/安全错误用例后需复验。
- 首次离线原生单测配置/BuildConfig生成成功，但因Debug模式integration_test插件引用的androidx.test rules/runner 1.2.0及espresso 3.2.0未缓存而失败。按正常Flutter --pub构建刷新插件注册后重试，不手改生成文件、不升级依赖。
- 构建入口安全错误补充后Python9项通过；共用私有写入工具的直接调用方模型配置3项通过；真实test入口plan-only与Android-only校验通过，不输出值。Git差异敏感字面量扫描、三环境忽略/600权限、UI/iOS范围及iOS私有文件字节核对通过。
- 进程诊断曾误输出含编码Dart配置参数的命令行，已停止使用完整命令行检查，后续仅核对进程名/退出状态；未将参数写入仓库或报告。

## 最终验证
- Python：凭据工具7项、入口9项、真实Gradle脚本合成回归6项、私有写入直接调用方模型3项、含cloud-pro保留用例的隔离生命周期16项，共41项通过。Gradle合成测试确实执行，没有跳过。
- Flutter可信来电目录126项通过，flutter analyze --no-pub无问题；未运行全量业务回归。
- JDK17/Flutter3.32正常 `flutter build apk --debug --pub --target-platform android-arm64` 编译通过，沿用已批准1.0.52(45)，仅开发编译验证，未正式导出交付或安装。Debug正常包含integration_test；首次离线失败所缺的同版本测试AAR已在正常联网构建补齐，未修改或升级依赖。
- 离线重试 `:app:testDebugUnitTest --tests 'com.vvtech.phone_agent.TrustedCaller*' -Ptarget-platform=android-arm64`：10套26项全部通过。
- APK供应商运行时SHA256、AAR重复类、19项SDK/Glide定义及清单组件检查通过；可信读取器DEX仅一份，BuildConfig与所选私有文件一致，未将整个cloud JSON作为资源打包。此检查不代表真实SDK服务可用。
- 真实Gradle依次选择test/dev生成BuildConfig并安全核对所选值一致；pro执行help在APP_ENV校验拒绝，符合本机生产配置待补齐状态。未放宽生产Release门禁。
- OpenSpec全量199项通过；差异检查、真实可信凭据字面量扫描、私有配置Git忽略/600权限、iOS私有字节及UI/iOS无改动核对通过。
- macOS无pwsh，Windows入口及PowerShell用例仅修改未运行；生产有效配置/正式发布、真机SDK及真实来电未验收。未提交推送，保持active。
