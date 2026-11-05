# 可信来电 Android 运行时

sdk.jar复制自指定Android参考项目app/runtime/sdk.jar，本工程使用本地implementation依赖，不引用参考目录。该依赖包含613个class；与本地可信来电和身份AAR无重复class。

SHA256：79948c1ab28536cd6498ad852476390ce962b5423b0351def3a6f4aab6979198。

仅复制AAR会遗漏ChakenNetworkConfig、Builder、LogTestUtil等运行时类。参考工程已有防回归测试，Flutter保留其关键构造方法和Builder字节码校验于TrustedCallerRuntimeBytecodeTest；不重新修补厂商二进制。

构建后必须执行：

```sh
python3 tool/check_trusted_caller_apk.py build/app/outputs/flutter-apk/app-debug.apk
```

检查哈希、AAR重复类，以及DEX class_defs中的实际类定义。字符串引用不算定义。该检查通过不等于真实SDK授权或设备交互验收通过。

2026-10-13：同步aiassistant_app cb94bbd工程副本，包含FormBody编码/解码兼容修复。身份规范化由宿主拦截器执行，凭据仍仅从现有忽略的本地安全配置读取；不复制参考工程明文凭据。
