# 设计

修改位于 commerce data 层。CommerceCatalog 明确要求 Map<String,Map<String,Object?>>，原来的映射回调里 Map.unmodifiable 未取得内层上下文，非空权益实例保留 dynamic 泛型并在外层类型转换时失败。修复只补 Map<String,Map<String,Object?>>.unmodifiable 与 Map<String,Object?>.unmodifiable，不加入兜底、类型宽松转换或异常吞掉。

新独立回归文件只负责非空发布目录消费者行为：JSON 字符串经 jsonDecode 模拟网络响应的运行时类型，包含四档权益和会员/积分包商品，验证具体数值、两层不可变性、CatalogController 成功态及营销身份分离。坏权益结构仍须 FormatException。已有未发布目录、HTTP404、服务端500等测试一起执行。

不将解析问题塞入 controller/page；同类 DTO 容器仍在 data 自身声明泛型，不改变领域模型或 API 契约。采用每批不超过3文件，先观察实际 RED 再修；仅定向测试、analyze、OpenSpec 和 UTF-8/diff 校验。构建、设备与模型根因由主代理继续。
