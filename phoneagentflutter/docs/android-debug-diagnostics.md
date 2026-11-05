# Android Debug 本地诊断读取

仅 Android Debug 构建生成可读诊断副本，事件仍沿用现有脱敏字段、账号作用域、水位和轮转。正式加密档案继续作为唯一权威，Debug 与 Release 同包名覆盖时不改变档案格式；副本写入失败不阻断记录或上传。Release / Profile 不生成可读副本，不开启 debuggable，也不扩大文件共享权限。

Debug 副本位于应用私有的相对目录 `files/diagnostics-v2/readable-debug/<scope-hash>/`。授权 USB 调试后，通过实际已安装 Debug 包名读取；普通 Debug 默认包名与测试签名 Debug 包名按各自构建配置确定，不要把 Release 读不出误判为日志丢失。

```powershell
adb shell run-as <debug-package> find files/diagnostics-v2/readable-debug -name 'log-*.jsonl'
adb exec-out run-as <debug-package> cat files/diagnostics-v2/readable-debug/<scope-hash>/<log-file>.jsonl
```

`index.json` 说明已提交文件与水位；读取期间正在追加的文件可能变化，应以已提交索引为准。历史加密档案在 Debug 读取或追加时生成对应可读副本，实际尚未刷新到磁盘的事件不由 ADB 命令强制刷新。上传成功继续只清理对应水位的数据。

Release 的本地免上传排查可以通过用户主动导出诊断 ZIP、系统文件保存或临时文件授权分享实现。该方案不要求放开 run-as，但属于另一个功能范围；本轮没有自动新增导出入口或修改权限。
