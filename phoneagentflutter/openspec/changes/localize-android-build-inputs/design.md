# 设计

1. 2026-10-19 用户纠正后复用现有 cloud-dev/cloud-test 的 device-defines.json；已核对与新增副本完全相同，切换入口后删除 `.local/android/config` 重复副本；环境和必需凭据只校验，不输出内容。登记 keystore 按字节复制，属性仅改为相对 registered.keystore；目录700、文件600。
2. Windows 入口默认使用工程固定路径，配置路径固定为 `.local/cloud-test/device-defines.json`；显式签名路径只能在工程 `.local/android/signing` 内。Gradle 以 canonical path 同时拦截属性和 keystore 的越界及符号链接逃逸；不再回退外部目录或 debug key。
3. 新增标准库 Python macOS 入口，使用同一固定目录，默认 Release/ARM64/--pub；版本号显式传入，Flutter/JDK 版本检查保留。子进程环境隔离保证成功失败均不污染调用者环境。
4. dev 和本地 Docker 入口仅迁移配置来源，不扩大设备操作范围。test 仍使用原证书 MD5 ebd4c931de412bf5d9c3716815389097，生产门禁不变。
5. 合成私有输入及假 Flutter 覆盖缺失、环境错误、路径逃逸、Release 参数和失败传播。实际签名由 Gradle 和成包 apksigner 验证。按已批准1.0.52(45)执行一次 Release 编译，不安装，不创建打包报告。
6. 私有内容只保存在忽略目录，历史快照及外部原件保留；此侧聊不改变主线程分支或提交状态。迁移后的输入文件属于本机构建依赖，克隆新工程需由维护者安全配置同一路径。
