# 固定身份采集 SDK

Vendor 为现有 iOS 项目 `ddb996a28f98559ea7d8b76ca9d7712703dedbc1` 的
`iOS/PhoneAgent/PhoneAgent/ThirdLib/AliyunIDPro_iOS_2.3.50` 原样文件。
仅用于本产品集成；供应商版权、使用许可及限制保持不变，不声明开源授权。

本地 Pod 管理框架链接及资源复制，Classes 中是本项目自有薄通道。
所有认证判断、服务端 HTTP 和计费仍在共享 Dart 层；注册不初始化 SDK。
SDK 不支持模拟器认证，实际权限/退出/相机释放需真机验证。

本 Pod 使用静态链接，8 组资源 bundle 复制到主 App 根目录。
供应商文件禁止 Git 文本转换；来源/打包校验命令及取消限制见
`docs/engineering/IDENTITY_SDK_VALIDATION.md` 与 `scripts/verify-identity-sdk.ps1`。

Android 同版本 SDK 固定在 `android/app/libs/identity`，来源为 Android v65
`4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 8 个认证 AAR，不含可信来电 SDK。
