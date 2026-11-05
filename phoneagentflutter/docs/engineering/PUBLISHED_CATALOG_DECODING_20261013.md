# 已发布商业化目录解码修复

## 事实与范围

主代理在1308手机观测 catalog/current 两个GET均HTTP200/000000、目录7商品，并在当前数据解析时得到 UnmodifiableMapView<dynamic,dynamic> 到 Map<String,Object?> 的类型异常；membership解析正常。本代理没有读取该账户响应或私人夹具，以完全合成JSON重现同类失败。

目录 data 层原来在 benefitsByLevel 映射回调中创建未声明泛型的 Map.unmodifiable。空档位不会实例化内层值，旧空目录测试没有暴露问题；非空档位的 dynamic Map 值在外层类型转换时失败。修复只为外层 Map<String,Map<String,Object?>> 与内层 Map<String,Object?> 明确类型，不改变商品/协议校验、HTTP错误、域模型、控制器或UI空态。

## RED 与 GREEN

独立 `published_catalog_decoding_test.dart` 使用 jsonDecode 合成四档完整权益及两件会员/积分包商品，不含账户、部署或真实商品数据。

- 实际RED：3项中1通过、2失败。直接DTO测试得到主代理观测的同类TypeError（commerce_dto.dart原91行），控制器测试得到“会员与商品加载失败，请重试”；坏权益对象拒绝通过。
- GREEN：解析与控制器成功；商品及四档数值完整，两层Map不可变，营销切档不改变FREE实际身份；null/array权益继续FormatException。
- 第一组16通过：新发布目录、DTO、服务端契约兼容及目录控制器。
- 第二组26通过：未发布目录、服务可用性（合成HTTP404/500保持错误）及逐商品原价契约。两组选择不同文件，不重叠相加，共42项定向。
- analyze无问题（25.0秒），OpenSpec全量98/98及本change strict通过，中文UTF-8回读与diff通过（仅既有LF→CRLF提示）；本轮不构建、不安装、不推送，模型空问题仍由主代理独立取证。

实际测试命令（固定Flutter3.32.0/Dart3.8）：

```powershell
# RED，仅新文件，修复前运行
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/published_catalog_decoding_test.dart
# GREEN两组
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/published_catalog_decoding_test.dart test/features/commerce/commerce_dto_test.dart test/features/commerce/server_contract_compatibility_test.dart test/features/commerce/catalog_controller_test.dart
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/unpublished_catalog_test.dart test/features/commerce/commerce_service_availability_test.dart test/features/commerce/membership_product_price_dto_test.dart
D:/tools/flutter-3.32.0/bin/flutter.bat analyze --no-pub
openspec validate --all
openspec validate fix-published-commerce-catalog-decoding --strict
```

本机安全日志前缀 `D:/Temp/story1837-published-catalog`，后缀 `-red.log`、`-green.log`、`-boundaries.log`、`-analyze.log`、`-openspec.log`。没有读取用户私钥、证书或defines，没有网络业务请求、付款、短信、外呼、手机操作或数据库写入。真机目录正常展示须以主代理后续新包复验，不能以本地GREEN代替。
