# 本机通话元数据与开发者列表操作

2026-09-18，`contacts-migration` 2.9a、`settings-interactions` 2.2d4。共享 Flutter 交互优先，视觉后校准；本批不代表联系人/翻译/设置模块全部验收。

## 固定来源与范围

Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：

- `AssistantCallRecordState`、`FinalCallRecordStorage`：按账号本机记录；普通记录追加，带 callId 的翻译结果按 id/kind 去重。
- `AssistantSystemPhoneCallRecordPolicy`、`AssistantRootDialSystemPhoneCoordinator`：系统电话交接成功记普通记录，不能把“已拉起系统电话”写成“已接通”。
- `AssistantClientCallRecordPolicy`：翻译结束生成本机拨号元数据；成功、失败均有记录，不等价于服务端录音归档完成。
- `AssistantDeveloperDataModeActions`、`AssistantContactRuntimeController`：Filled/Empty 都清空本机 App 记录；Filled 刷新任务、静默重读已授权联系人，Empty 清联系人内存；两者重置选择。未删除系统数据或后台任务。

当前任务页继续消费原来的后台来源，不迁入旧 Calls 页面和旧通话详情。不保存本批消费者不需要的全文转写、录音或任务详情，不把联系人历史关系功能带回来。

## 数据与交互流

| 组件/方法 | 行为与边界 |
|---|---|
| `DialerController.dial` → `onOpened` → `AppDialHistoryRecorder.systemHandoff` | 成功交接一次追加；抓取发起时号码/姓名/国家，离开拨号页仍可记录；账号仓库独立拒绝旧登录。失败不自动重拨；MOCK 不调用正式记录回调 |
| `SecureAppCallRecordRepository.load/append/clear` | 环境/API/账号 SHA-256 槽位；复用安全存储适配；同槽跨实例串行读改写，校验 schema/scope。未知或损坏数据失败可见，不当空数据覆盖 |
| `AppCallRecordCodec.encode/decode` | v1 元数据：id/kind/号码/姓名/时间/国家/双方语言，统一 App 来源；不记录连接成功结论、录音或完整字幕 |
| `AppDialRecentSource.load/changes` | 正式 App 来源只输出 translation 记录；系统 CallLog 为独立来源，iOS 不读取系统日志 |
| `DialRecentController.load/_invalidate` | 本机变更刷新最近列表；在途旧读取失效，合并一次后续刷新；手动重复刷新保持单飞；销毁取消订阅 |
| `DeveloperListController.apply` | 清空成功后才继续其他消费者；Filled 刷新任务和联系人，Empty 只清联系人内存。部分刷新失败明确显示，不谎报清空回滚，不请求 OS 撤权 |
| `ContactsController.clearDeviceForDeveloper/loadDevice` | 清内存与详情选择使旧读取失效；等待已有读取完成；不改系统权限和备注目录，不持久化一个“永远空”的过滤模式 |
| `developerListControllerProvider/contact_providers` | 当前登录生命周期内保留离页状态；账号代次切换销毁旧控制器；离页任务刷新使用临时监听，避免 autoDispose 提前取消 |

正式普通拨号页和翻译拨号页的普通模式均接同一记录回调。真正的翻译 Finished 写入仍待媒体正式装配，本批只完成其本机仓库和正式读取端口，不伪造已发生的翻译记录。

## 自动验证与演练

- 新增 35 项：存储/codec/来源/记录器 15、开发者控制器 8、拨号交接 3、最近记录事件 2、联系人读取/清空 2、三宽度页面与正式消费者 4、正式账号持久 provider 1。
- 全量 1707 项通过；analyze 无问题；783 个 Dart 文件格式检查、OpenSpec 19 项通过。
- 正式 Web、Android Debug、Mac iOS Debug 无签名构建通过。既有 Web Cupertino 字体警告仍在，构建不等于图标视觉或真机验收。
- 浏览器 `http://localhost:8106/`，入口 `tool/previews/app_call_records_preview.dart`；也可从“开发者功能演练”进入“本机记录与列表演练”。复用正式最近列表/开发者组件、控制器和真实 codec/串行仓库，仅存储/系统联系人/任务输入是内存合成。
- 浏览器确认追加→号码选择→模拟保存失败→清空失败保留→关闭故障→清空成功（联系人 0，系统记录保留）→充实（联系人 3、任务刷新 1）。Widget 在 320×568、390×844、430×844 覆盖相同流程。
- 合成正式 provider 验证容器重建恢复、token 刷新不换仓库、账号切换隔离、旧引用拒绝、离页 Empty 保留和 Filled 重置选择。
- 联系人适配器同步抛错也规范为异步完成，避免在途句柄被已完成操作占用而无法重试；沿已有用例补失败后再次读取的断言。
- 私有测试/构建日志位于 `.local/app-call-record-*`，不提交；没有对真实账号进行清空、通话、备注写入、短信、系统授权或新安装。原 8080 登录和 Mac 保留的签名会话未改。

## 尚未完成 / 集中真机验收

1. 翻译 Finished 的共享一次本机记录/账号工厂/provider已由2.2d完成并合成验证，见 [结束接续验证](TRANSLATION_FINISHED_VALIDATION.md)；实际拨号总装配、后台归档完成与历史刷新仍待接线，本机元数据不替代后端任务/录音。
2. 2026-09-20已实现旧 Android `final_call_records_<account>` 元数据只读导入，77条定向及Android Debug通过；新信封优先、清理不复活，见[迁移实现与集中步骤](LEGACY_CALL_RECORDS_MIGRATION_VALIDATION.md)。真实同签名 OTA 尚未验收，当前独立 debug 槽位不冒充正式升级证明。
3. Android 真机系统拨号交接/进程恢复、系统 CallLog 权限撤销/重授、锁屏安全存储；iOS 仅 App 记录及系统电话交接。构建产物未安装，不自动打真实电话。
4. 系统授权联系人下 Empty/Filled、后台任务不受清空影响；此项实际清理本机记录，执行前需单独确认测试数据。
5. 音频/SDK/真实翻译、模拟权限剩余消费者、最终视觉与整体迁移仍有待办；本次子任务完成不归档父变更。
