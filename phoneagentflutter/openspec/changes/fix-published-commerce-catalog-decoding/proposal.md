# 修复已发布目录权益解析

## Why
真实手机目录和当前会员请求均成功，但目录包含非空四档权益时，Dart 嵌套 Map.unmodifiable 缺少泛型，产生 UnmodifiableMapView<dynamic,dynamic> 到 Map<String,Object?> 的类型异常。旧空目录回归无法触发该错误。

## What Changes
- 用完全合成的 jsonDecode 发布目录先重现类型异常。
- 为目录权益外层及每档内层不可变 Map 明确泛型，不改变业务校验或 UI 空态。
- 验证商品/权益保留、控制器成功加载及坏数据继续失败。

## Impact
只涉及商业化 data 解析与其直接消费者回归，不修改模型、服务路由、原生支付或后端。本批不构建、不安装、不推送，不读取私人配置或实际账户夹具。
