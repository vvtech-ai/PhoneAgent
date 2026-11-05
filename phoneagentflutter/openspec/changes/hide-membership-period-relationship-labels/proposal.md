# 移除会员周期卡购买关系标签

## Why
用户于2026-10-28确认删除月卡/季卡/年卡旁的“升级”“续购”，保留底部按钮及购买处理。

## What Changes
- 移除MembershipPeriodCard关系标签及唯一使用的membershipPurchaseLabel函数。
- 更新原有标签和刷新回归，保留套餐名称、价格、折扣、选中和点击验证。

## Impact
仅PhoneAgent Flutter commerce展示层与相关测试；无后端、接口、存储、支付、权益或原生改动。
