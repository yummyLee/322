# 眩晕 Buff（StunBuff）实现记录

本文记录项目中「独立眩晕 Buff」的实现方式、接入点与当前语义。

---

## 1. 目标

- 不再复用 `SlowBuff(level=10)` 充当眩晕。
- 建立独立 `stun` Buff 定义，便于后续扩展：
  - 眩晕抗性
  - 禁攻击/禁施法
  - UI 单独图标与驱散规则

---

## 2. 代码结构

### 2.1 BuffDef 定义层

- 文件：`scripts/core/combat/buffs/defs/stun_buff_def.gd`
- 类：`StunBuffDef`（**不是 `BuffDef` 资源本身**，而是一个带 `static get_def()` 的工厂；内部缓存一份 `BuffDef` 对象，避免每次 apply 都重新构造）
- 核心配置：
  - `id = &"stun"`（`StringName`，与 `DEF_ID` 常量一致）
  - `polarity = 1`（Debuff）
  - `tags = [&"dispellable", &"hard_cc", &"stun"]`（全部用 `StringName`，方便 `has_tag` / `dispel_by_tag` 的 O(1) 命中）
  - `duration_policy = Timed`，`default_duration = 1.5`
  - `death_policy = RemoveOnDeath`，`time_source = GameTime`
  - `stack_rule = None`，`stacking_scope = PerSourceSkill`，`refresh_policy = KeepLonger`，`max_stacks = 1`
  - `effects = [ AttributeEffectDef(MOVE_SPEED, PERCENT_ADD, -1.0, Fixed) ]`

> 说明：当前版本仍通过属性效果实现“硬停住”——`MOVE_SPEED * (1 - 1.0) = 0`。  
> 语义上已是独立眩晕，后续可把“禁攻击/禁施法”挂到同一 `stun` Def 上（通过新增 `ControlEffectDef` 或追加 `ATTACK_SPEED = -1.0` 的 AttributeEffect）。

### 2.2 统一入口层

- 文件：`scripts/core/combat/buffs/stun_buff.gd`
- 类：`StunBuff`
- API：
  - `StunBuff.apply(target, duration, source_tag) -> bool`
  - `StunBuff.remove(target, source_tag) -> bool`
  - `StunBuff.has(target, source_tag) -> bool`

内部通过 `ApplyContext + BuffRuntime` 走统一管线，和 `SlowBuff` 一致。

---

## 3. 在重力阱中的接入

- 文件：`scripts/magic/effects/gravity_well_controller.gd`
- 结束效果由“向外推”改为：
  - `StunBuff.apply(target, 1.5, &"gravity_well_finish_stun")`

即：重力阱收束结束后，对外圈内敌对施加 1.5 秒眩晕。

---

## 4. 与追逐系统的联动注意点

为了让 `MOVE_SPEED=0` 的眩晕真正停住，需要保证追逐器不回退兜底速度：

- 文件：`scripts/enemies/chase/chase_controller.gd`
- `_resolve_move_speed()` 现逻辑：
  - 有属性时返回 `max(0, MOVE_SPEED)`
  - 无属性时才回退 `fallback_move_speed`

否则会出现“眩晕后仍移动”的假象。

---

## 5. 后续可扩展点

1. **行为层眩晕**：增加统一接口（如 `is_hard_cc_locked()`），攻击/施法脚本都查询该状态。
2. **抗性与免疫**：引入 `stun_resist`、`hard_cc_immune` 标签。
3. **UI 表现**：为 `stun` 显示独立图标与剩余时间。
4. **驱散策略**：按 `tags` 做“仅解 Debuff / 仅解硬控”的技能分层。

