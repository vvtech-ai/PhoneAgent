## 设计
遵循 app-foundation 已批准的平台身份安全要求，只替换主工程中两处 com.chaken.phoneagent.demo 为 com.chaken.phoneagent.test。两个扩展已经采用 .test 子标识，无需修改。网络 APP_ENV 与 Bundle ID 分开配置。

project.pbxproj 是 Xcode 工程元数据，已有 file_exceptions.md 例外；本次没有新增职责或逻辑，不拆分。

## 验证
运行 OpenSpec 全量校验、plutil 工程语法检查，解析 PBXNativeTarget 的三种构建配置核对 Runner 与两个扩展标识，执行现有通知配置检查与 diff 检查。当前系统 Ruby 缺少 xcodeproj 时，使用 plutil 解析后的工程对象检查身份；不安装依赖或重打包。签名与真机运行留待后续打包验收。
