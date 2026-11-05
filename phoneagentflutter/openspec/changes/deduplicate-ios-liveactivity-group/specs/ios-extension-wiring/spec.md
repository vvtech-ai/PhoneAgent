## ADDED Requirements

### Requirement: Live Activity工程引用幂等
接线脚本 MUST 按实际路径复用工程组和文件，保持业务及真实文件不变。

#### Scenario: path-only组和重复组
- **WHEN** 当前工程包含同目录重复组或仅path的既有组
- **THEN** 接线后 MUST 只保留一个组、一份必要构建引用，并保持配置关联有效

#### Scenario: 连续执行及现有嵌入阶段
- **WHEN** 连续执行两次或嵌入阶段已重命名
- **THEN** 第二次执行 MUST 不改变工程且不新增重复嵌入阶段
