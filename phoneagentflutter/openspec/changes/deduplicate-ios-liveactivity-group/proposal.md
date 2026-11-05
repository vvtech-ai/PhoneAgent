# 合并重复Live Activity工程组

用户2026-11-03批准仅iOS引用及接线脚本修复，业务功能不变。保留主工程当前Xcode未提交设置及scheme，复制到独立工作树作为输入，不修改主工程。两个group实际指同目录、仅一target；脚本只按name查找，path-only组不命中。修复group查找、引用合并及幂等，防资源/嵌入阶段再重复。
