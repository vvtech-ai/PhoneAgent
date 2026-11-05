# 隔离打包临时目录生命周期

## 当前入口

后续需要创建 `.local/test-build-*` 的 Android/iOS 隔离打包，统一通过 `python3 scripts/run-test-build.py` 调度。工具自动创建唯一目录，不接管现有目录，也不执行历史目录扫描。

已有 `build-task-test-apk.py`、PowerShell Android 入口在当前工程直接构建，不创建 test-build 目录；`verify-ios.sh` 只做开发编译验证，不是完整交付入口。本次不改写这些命令的含义。若需要隔离源码构建，由本次构建阶段准备 `source/` 及必要的临时私有输入，调用既有平台构建逻辑，且所有子进程结束后才能返回成功。

## 参数与顺序

- `--build-command`：JSON字符串数组，执行准备隔离源码和实际构建的命令。
- `--verify-command`：JSON字符串数组，执行当前平台的完整成包验证；必须通过退出码反馈结果，不得传入空验证或无操作命令。
- `--artifact`：可重复，JSON对象包含工作区相对 `source` 路径和最终交付 `name`。仅允许非空APK/IPA；文件名沿用用户批准版本及既定命名规则，不在此入口自动递增版本。
- `--ios-environment`：声明 IPA 时必须显式选择 prod/test/dev；平台验证后自动检查最终签名邀请配置，失败不导出。APK 不需要此参数，完整平台验证命令仍须提供。参见 [iOS 三环境邀请配置](IOS_INVITE_ENVIRONMENT_CONFIGURATION.md)。

命令参数支持 `{repo}` 和 `{workspace}` 占位符，以数组形式直接启动进程，不经过shell解释。两阶段工作目录均为本次临时目录；业务配置来自cloud-dev/cloud-test，可信来电配置需安全准备在隔离源码根目录的local.properties，登记签名来自`.local/android/signing/`，不建立新的常驻副本或回退父工作区。参数中只传路径，不传真实口令、token或凭据内容。

以下为接线模板，两个平台脚本需由当前打包任务提供，不能把此模板直接当作现成平台构建脚本执行：

```bash
python3 scripts/run-test-build.py \
  --build-command '["python3","{repo}/<当前任务构建脚本>.py","--workspace","{workspace}"]' \
  --verify-command '["python3","{repo}/<当前任务平台验证脚本>.py","--workspace","{workspace}"]' \
  --artifact '{"source":"source/build/<已验证产物>.apk","name":"Phone_Agent_TEST_<用户批准版本>_<用户批准版本号>_test_<上海时间>.apk"}'
```

iOS使用`.ipa`；双端交付可以重复声明两个产物。平台验证继续遵循AGENTS现有身份、签名、环境、版本及供应商库等检查；本工具只管理执行顺序、文件完整性和清理，不能替代这些验证。验证期间不得改写产物，所有声明的文件必须在验证前已经生成。

## 清理规则

1. 构建成功后记录每个源产物SHA256，执行平台验证，再检查源文件未改变。
2. 在 `deliveries/` 下创建独立交付目录，以临时文件复制、核对SHA256、原子重命名；不覆盖已有产物。`.gitignore`仅用于保护交付包，不生成构建日志或回执文件。
3. 所有产物完整导出后，重新核对本次目录路径、设备和inode，再自动清理该目录。路径和SHA256仅输出到当前会话。
4. 构建、验证、导出失败或在这些阶段中断，保留本次目录并返回失败；已失败的目录不会在后续任务自动重用或清理。
5. 导出完成后清理失败，仅提示残留目录，交付仍成功。平台若不支持防链接攻击的安全清理，也保留目录，不降级为通配删除。

常驻cloud-dev/cloud-test、签名、deliveries，以及其他任务/历史test-build目录均不在删除范围。用户另行要求清理历史目录时，应单独核对，不通过此工具扩大删除范围。

## 开发验证

`python3 -B -m unittest discover -s scripts -p test_test_build_workspace.py -v`

使用临时测试工程、合成APK/IPA内容及模拟构建/验证命令；不调用Flutter、Xcode、真实签名或安装，不对实际旧打包目录做删除测试。Python代码使用标准库；本轮验证平台为macOS，Windows实际目录清理未验。
