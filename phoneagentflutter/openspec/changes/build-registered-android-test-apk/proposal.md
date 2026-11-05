# 构建已登记身份的Android测试包

## Why
当前Flutter Debug固定.dev，支付宝已登记.test及指定证书，不能将开发包当测试包交付，也不能放宽生产Release门禁。

## What Changes
- 显式PHONEAGENT_ANDROID_ENV=test只覆盖Debug包名和测试签名；默认dev、Profile及Release门禁保持。
- 独立Gradle配置读取外部签名属性并校验登记证书DER MD5，缺配置或非法环境失败。
- 独立PowerShell构建入口校验test私有参数、固定Flutter及test地址；临时环境变量finally恢复，不输出密码。

## Impact
Android测试构建配置、脚本和定向回归。主代理在集成后实际构建，此change实施不代表APK已产出、安装或真实支付已验证。
