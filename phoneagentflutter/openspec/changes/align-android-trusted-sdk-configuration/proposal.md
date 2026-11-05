# Android可信来电SDK配置对齐

## 问题
用户确认以aiassistant_app 8f23592018a6665194f735f5860179571ce14a98为参考。Android当前同值凭据被test/pro生成标签隔离，测试Release可能读不到配置；prepare正常返回不代表SDK可用，现有诊断会误记成功。两份设备日志未包含linked/configured，尚不能唯一证明设备故障根因。

## 范围
统一Android所有合法构建的可信SDK凭据，保留包名/业务环境合法性校验；复用既有Application初始化及进程缓存，完善失败分类和Android准备诊断。保留Flutter UI、账号保护、首次SDK引导及后续设置入口，不把打开视为授权。

iOS代码、SDK、凭据和生成结果不变；业务API、包名、签名、版本和Release门禁不变。密钥仅生成到忽略文件，不提交、不输出。
