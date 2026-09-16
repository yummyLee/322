# Buff 系统设计记录

## 1. 文档目的

- 定义一套**统一挂载在战斗单位上**的 Buff/Debuff 运行时模型，**玩家与怪物共用同一套接口**。
- 区分：**属性型效果**（可走现有 `StatModifier`）、**非属性型效果**（位移限制、禁用技能、强制动画、伤害改写等）。
- 约定**持续时间策略、叠加规则、驱散与免疫**，便于后续实现与平衡。

本文档为**设计层**说明；具体类名可与实现时微调，但语义建议保持一致。

### 1.1 当前实现状态（与本文档对照）

> 下表按本文的里程碑（§11）整理。**标 🟢 的模块已在代码中落地**，读者可对照 `scripts/core/combat/buffs/` 下文件；**🟡 部分落地**的模块本文的字段/语义在代码里存在但行为未全写；**🔴 未实现** 的仅供后续参考。

| 文档章节 | 实现状态 | 代码位置 / 备注 |
|---|:---:|---|
| §4.1 `DurationPolicy`（Timed / Permanent） | 🟢 | `buff_enums.gd` |
| §4.2 `DeathPolicy` | 🟢（只实现 `RemoveOnDeath` / `PersistThroughDeath`，**未实现** `RemoveOnDeathButPersistOnRespawn`） | `buff_enums.gd` |
| §4.3 `TimeSource` 枚举 | 🟡 枚举已定义，但 `BuffRuntime.tick(delta)` 目前只吃上游传入的 `delta`，**未按 `GameTime / RealTime` 分流**。`scene_local` 未实现。 | `buff_enums.gd`、`buff_runtime.gd` |
| §5.1 `StackRule` | 🟢 | `buff_enums.gd`、`buff_runtime.gd._apply_onto_existing` |
| §5.2 `StackingScope` | 🟢 | `buff_runtime.gd._compute_key` |
| §5.3 `RefreshPolicy` | 🟢（4 策略全实装） | 同上 |
| §5.4 `MutexGroup` | 🟢 基本互斥生效 | `buff_runtime.gd._handle_mutex` |
| §5.5 `max_stacks` / `MaxStackBehavior` | 🟢 | 同上 |
| §5.6 容量驱逐（`capacity / EvictLowestPriority`） | 🔴 未实现 | — |
| §6.2 `ApplyContext` | 🟢（字段名以代码为准：`stacks_override`、`duration_override`，**非**文档早期草案里的 `stack_override`） | `apply_context.gd` |
| §6.3 查询接口 | 🟡 目前 `has_buff / get_stacks / get_remaining_time` 只支持 `def_id`；按 `tag` 查询尚未实现。`list_buffs()` 无 filter 参数，过滤由调用方做。 | `buff_runtime.gd` |
| §6.4 `ApplyResult` | 🟢（Applied / Refreshed / Stacked / Immune / Rejected 已用；**`Replaced` 枚举值保留但目前无代码构造**） | `apply_result.gd` |
| §7 驱散 / 标签 / 免疫 | 🟢 `dispel_by_tag` + `set_immune_tag / set_immune_mutex_group` 已落地 | `buff_runtime.gd` |
| §8.1 `IBuffEffect` 生命周期钩子 | 🟡 `on_apply / on_remove / on_tick` 已接线；`on_damage_taken / on_damage_dealt / on_kill / on_crit` **接口留白但 `CombatantComponent` 尚未触发**。 | `buff_effect.gd` |
| §8.1a `tick_interval` | 🟢 但 **`tick_interval == 0` 当前语义是「不调度 on_tick」**（见 `BuffRuntime.tick`），**与文档早期"每帧调用"表述不一致，请以代码为准**；`tick_on_apply` 未实现。 | `buff_runtime.gd` |
| §8.1b ControlFlags 引用计数 | 🔴 `CombatantComponent` 上**没有** `silence_count / stun_count / disarm_count / root_count` 等字段。当前"眩晕"通过 `StunBuff` 的 AttributeEffect（`MOVE_SPEED=0` + `ATTACK_SPEED=0`）模拟行为上的停顿，不是真正的控制门控。 | `./眩晕Buff实现记录.md` |
| §8.2 伤害管线钩子（`DamagePhase + priority`） | 🔴 未实现；`BuffEffect` 的空钩子存在但 `CombatantComponent` 的伤害结算流程尚未调用。 | `combatant_component.gd` |
| §8.3 `BuffEffectDef` 子资源体系 | 🟡 **只实装了 `AttributeEffectDef`**（`effects/attribute_effect_def.gd`）；`ControlEffectDef / DotEffectDef / DamageHookEffectDef / ScriptEffectDef` 均未实现。 | `effects/` |
| §8.4 Snapshot 策略（SnapshotOnApply / Dynamic / Hybrid） | 🔴 `BuffDef` 无 `snapshot_policy` 字段；当前 DoT 等效用「从 caster 即时读取」处理（尚无 DoT 效果类）。 | — |
| §8.5 两阶段 tick（Advance → Flush） | 🟢 | `buff_runtime.gd.tick` |
| §9 过期顺序（按 `priority` 降序） | 🔴 当前 `_pending_expire` 按 append 顺序处理，未按 `priority` 排序 | `buff_runtime.gd` |
| §9.1 存档 schema / `save_policy` | 🔴 未实现 | — |
| §10.1 `SlowBuff` 迁移 | 🟢 `SlowBuff / StunBuff` 已改为**兼容入口**，内部走 `BuffRuntime.apply`；老签名 `SlowBuff.apply(target, level, duration, source)` 仍保留 | `slow_buff.gd`、`stun_buff.gd`、`defs/slow_buff_def.gd`、`defs/stun_buff_def.gd` |
| §10.2 调用顺序（buffs.tick → attributes.tick） | 🟢（**实际挂在 `CombatantComponent._process` → `tick(delta)`**，不是 `_physics_process`；顺序保持"buffs 先、attributes 后、再进 AI / 伤害"） | `combatant_component.gd` |

> 之后章节中**仍以设计层描述为主**，请先看上表判断某个小节属于 🟢 / 🟡 / 🔴，避免按文档直接写代码却跟实际行为对不上。

---

## 2. 设计原则

1. **战斗单位为中心**：Buff 挂在「可参战实体」上。当前工程里 natural fit 是 **`CombatantComponent`**（或在其下增加子节点 **`BuffRuntime` / `BuffComponent`**），而不是写在 `Player`/`Enemy` 各一份逻辑里。
2. **数据与实例分离**：  
   - **`BuffDef`（定义）**：id、分类、默认时长、叠加策略、是否可驱散、效果列表等——可来自资源（`.tres`）或表。  
   - **`BuffInstance`（实例）**：某单位身上的一条具体 Buff：剩余时间、层数、施加者引用、运行时状态。
3. **效果可组合**：一条 Buff 可包含多个 **Effect**，每个 Effect 负责一类行为（改属性、禁跳、每 tick 扣血等）。
4. **与现有属性系统协作**：属性变化**优先仍用** `StatModifier` + `CharacterAttributes`，由 Buff 的 **AttributeEffect** 在 apply/remove 时增删 modifier，避免两套数值公式。
5. **可测试、可观测**：统一 `applied` / `refreshed` / `expired` / `dispelled` / `immune` 等信号或日志，便于 UI 与调试。

---

## 3. Buff 分类

### 3.1 按极性（展示与部分规则用）

| 类型 | 说明 | 典型用途 |
|------|------|----------|
| **增益（Buff）** | 对宿主有利 | 加速、加攻、护盾、减伤 |
| **减益（Debuff）** | 对宿主不利 | 减速、易伤、中毒、沉默 |
| **中性** | 机制向，不一定好或坏 | 标记、层数载体、剧情状态 |

极性可用于 **UI 颜色、统计、部分天赋**（「只驱散减益」）；**驱散逻辑建议用独立标签**（见 §7），不要仅靠极性。

### 3.2 按效果形态

| 形态 | 说明 | 实现倾向 |
|------|------|----------|
| **属性类** | 改变 `final_stats` / `derived_stats` 能表达的数值 | 映射为 `StatModifier`（FLAT / PERCENT_ADD / PERCENT_MULT） |
| **特殊效果类** | 不（仅）改属性 | 独立 **Effect** 钩子：`on_apply` / `on_remove` / `on_tick`，或订阅全局事件 |

**特殊效果举例**（常见 ARPG / MMO 里与「属性」并列存在）：

- 控制：**眩晕、冰冻、击飞、沉默、缴械**（常需改状态机或输入门控，而非单一 stat）。
- 位移：**强制位移、钩锁、击退**（与物理/导航交互）。
- 伤害改写：**护盾吸收、伤害转治疗、单次免伤**（拦截 `HitContext` 或伤害管线）。
- 技能：**禁用某类技能、锁能量、反伤触发器**。
- 视觉/任务：**仅图标与任务计数**，无战斗数值。

---

## 4. 持续时间与生命周期

建议用 **策略枚举 + 参数**，而不是只用「一个 float 秒数」。

### 4.1 时长类型（`BuffDurationPolicy`）

| 策略 | 含义 |
|------|------|
| **Timed** | 有限时间；`remaining` 随 `tick(delta)` 减少，归零移除。 |
| **Permanent** | 无自动过期；直到被移除、死亡策略、或剧情清除。**「可驱散永久」与「不可驱散永久」的区别仅靠 §7 标签（`dispellable` / `undispellable`）表达**，不再设 `Infinite` 这类近义枚举，避免歧义。 |

### 4.2 死亡时行为（`BuffDeathPolicy`）

| 策略 | 含义 |
|------|------|
| **RemoveOnDeath** | 单位 `died` 时清除（多数临时 Buff/Debuff）。 |
| **PersistThroughDeath** | 死亡后仍保留；复活或重生后继续存在（部分 Roguelike 诅咒、剧情标记）。 |

> 早期草案里还有 `RemoveOnDeathButPersistOnRespawn` 这类细分，**当前代码的 `BuffEnums.DeathPolicy` 只保留了上面两种**；如果后续真的需要区分"同 Run 内复活"，加新枚举值时务必同步更新 `buff_runtime._on_host_died` 的清理逻辑。

### 4.3 其他常见边界（建议在 Def 上可配）

- **切场景**：默认随单位保留；若需「仅当前场景」，用标签 `scene_local` 在场景卸载时清掉。
- **暂停 / 时间源**：在 `BuffDef` 上直接存字段而不是只留钩子：
  - `time_source: { GameTime, RealTime }`——`GameTime` 在菜单/全局暂停时不递减（单机多数 Buff 的默认），`RealTime` 按真实时间递减（少数「冷却道具使用」类可能需要）。
- **离线**（若以后有持久化世界）：仍归属 `time_source`：新增 `OfflineGameTime` 即可，不要另起一套 tick 接口。

---

## 5. 叠加、刷新与互斥

参考 **WoW（刷新、叠层）**、**PoE（诅咒上限、同类覆盖）**、**自走棋（唯一羁绊）** 等，工程里建议统一下列概念。

### 5.1 叠加模式（`BuffStackRule`）

| 规则 | 行为 |
|------|------|
| **None** | 同源再施加：**不叠层**，仅按 `RefreshPolicy` 处理时间。 |
| **StackIntensity** | 每层独立或合并强度（如每层 +5% 易伤，有上限）。 |
| **StackCount** | 只叠层数，强度由 `stack_scaling` 查表/曲线得出。 |
| **ReplaceWeaker** | 保留较强实例，弱的忽略或缩短（常见于同名控制）。 |
| **IndependentInstances** | 不同来源各算一条（如不同施法者的同名 DoT 各跳各的）——慎用性能。 |

### 5.2 叠加作用域（`BuffStackingScope`）

**同一个 `BuffDef` 来自 3 个不同施法者，在目标上算 1 条还是 3 条**——这是一个必须在 Def 上显式回答的问题，直接决定 `BuffRuntime` 内部以何为 key：

| 作用域 | 行为 | 典型用途 |
|--------|------|----------|
| **PerTarget** | 目标身上该 def 只有 1 条；再施加由 `StackRule + RefreshPolicy` 处理 | 大多数普通 Debuff/Buff |
| **PerCaster** | 每个施法者在目标上各一条 | 多人/多怪同时给同一 DoT，各算各的 |
| **PerSourceSkill** | 按 `source_skill_id` 或 `source_tag` 区分 | 你当前 `SlowBuff` 的「frost_trail / bramble_cage 各占一槽」 |

### 5.3 刷新策略（`BuffRefreshPolicy`）

与 `StackRule` 正交，统一由 Def 指定，**不允许各 Def 自己发明**：

| 策略 | 行为 |
|------|------|
| **KeepLonger** | `remaining = max(old, new)`（默认） |
| **Reset** | 始终用新施加的时长覆盖 |
| **AddDuration** | `remaining += new`（可配上限） |
| **KeepShorter** | 少见，用于「控制缩减」类 |

### 5.4 互斥组（`MutexGroup`）

- 同一组内**最多存在一条**（例：`控制_硬控` 组里眩晕与冰冻互斥，或只取最长）。
- 与「叠加模式」正交：先判互斥/优先级，再判叠层。

### 5.5 最大层数与层数映射

- `max_stacks`：达到后行为：**丢弃新施加** / **仅刷新时间** / **重置为满层并刷新**（需可配）。
- `stack_scaling`：`StackCount` 规则下强度与层数的关系，可选：
  - **LinearPerStack**：`value = per_stack_value * stacks`
  - **Table**：`Dictionary[int, float]`（显式每层数值，像当前 `SlowBuff.LEVEL_TO_PCT`）
  - **Curve**：`Curve` 资源（非线性，如易伤前期陡后期缓）

### 5.6 容量与优先级

某些类型的 Buff 在目标身上有**上限**（PoE 诅咒上限、"减益槽上限 5"之类）：

- `MutexGroup` 或 `Tag` 可挂 `capacity: int`；
- 超容量时的行为：`RejectNew` / `EvictLowestPriority` / `EvictShortestRemaining`（Def 里配）。
- `BuffDef.priority: int`——默认 0；同组内用于驱逐与「强控覆盖弱控」。

---

## 6. 玩家与怪物的统一接入

### 6.1 载体

- 任意带 **`CombatantComponent`** 的节点（玩家、怪物、召唤物、可攻击 NPC）均可挂 **`BuffRuntime`**。
- **施加入口**不区分阵营：统一 `BuffRuntime.apply(context)`；**敌我过滤在技能/弹道命中时**已完成，Buff 层只信「该不该施加」的 `ApplyContext`。

### 6.2 `ApplyContext`（建议字段）

- `def` / `def_id`：`BuffDef` 引用  
- `caster`：内部以 `WeakRef` 持有，通过 `get_caster()` 获取（统计、吸血、击杀归属）  
- `source_skill_id`：便于日志与成就  
- `source_tag`：`PerSourceSkill` 作用域的 key；SlowBuff 的 `"frost_trail"` / `"bramble_cage"` 等  
- `duration_override`：覆盖默认时长（> 0 生效；<= 0 则用 `def.default_duration`）  
- `duration_scale`：来自施法者的「持续时间延长」  
- `stacks_override`：特殊技能强制层数（> 0 生效）  
- `is_critical` / `hit_context`：可选，供触发类 Buff 使用  

### 6.3 查询接口（供 AI、UI、脚本）

- `has_buff(def_id | tag)`  
- `get_stacks(def_id | tag)`  
- `get_remaining_time(def_id)`  
- `list_buffs(filter)`：UI 图标列表；**UI 默认排序**：极性分组（Buff / Debuff / 中性）→ 剩余时间升序 → 层数降序，避免图标列表"跳来跳去"。

### 6.4 `ApplyResult`（施加返回值，一等公民）

`BuffRuntime.apply(ctx)` 的返回值必须能让调用方（技能脚本、UI、AI）做出反应（飘字、"施加失败退费"、"已经免疫则换备选效果"）。

```
enum ApplyResultKind {
    Applied,       # 新施加一条
    Refreshed,     # 刷新时长（同 def 已存在）
    Stacked,       # 叠层成功
    Replaced,      # 替换掉了组内/同 def 的旧实例
    Immune,        # 免疫（按 tag / mutex_group 命中）
    Rejected,      # 其他原因（容量满、优先级不够、死亡等）
}

struct ApplyResult {
    kind: ApplyResultKind
    instance: BuffInstance        # Applied/Refreshed/Stacked/Replaced 时有效
    reason: StringName            # Rejected/Immune 时的原因标签
    stacks_after: int
    duration_after: float
}
```

调用方应只依赖 `kind`，`reason` 用于日志与飘字本地化 key。

---

## 7. 驱散、免疫与标签

### 7.1 标签（`BuffTags`）

用 **位标记或字符串集合** 描述行为，避免硬编码 id 列表：

- **可驱散**：`dispellable`、`magic`、`curse`、`physical`（参考 WoW 驱散类型；是否采用看项目体量）。  
- **不可驱散**：`undispellable`、`boss_aura`。  
- **不参与统计**：`hidden`（仅逻辑用）。  
- **死亡清除**：可用 `death_policy` 表达，也可额外 tag 覆盖。

### 7.2 免疫

- 单位身上可有 **`BuffImmunity`** 列表或掩码：`immune_tags`、`immune_mutex_groups`。  
- 施加时：**先判免疫**，再判叠加；返回 `ApplyResult.Immune` 便于飘字或日志。

---

## 8. 效果层接口（建议形状）

以下为 **逻辑接口**，实现可用 `RefCounted` + 多态，或小型策略表。

### 8.1 `IBuffEffect`（概念）

**生命周期钩子**：

- `void on_apply(instance, host: CombatantComponent)`  
- `void on_remove(instance, host)`  
- `void on_tick(instance, host, dt)` — 按 `tick_interval` 调度（见下）  
- `void on_death(instance, host)` — **所有 Buff 都会被调用**；`RemoveOnDeath` 只是 runtime 在调用完这一轮后统一清理这批实例，从而让"死亡爆炸/死亡附赠 Buff"之类效果也能统一挂在这里，不走两套路径。

**触发事件钩子**（事件总线订阅，按需实现）：

- `void on_damage_taken(instance, host, hit: HitContext)` — 被命中
- `void on_damage_dealt(instance, host, hit: HitContext)` — 命中他人
- `void on_kill(instance, host, victim)` — 击杀结算
- `void on_crit(instance, host, hit)` / `on_dodge(...)` — 可选

ARPG 里大量 Buff 本质就是触发型（誓约庇护破盾、蝉蜕单次免伤、血印追猎、引魂灯连杀延时、岚雾迷踪"下一次必暴"……），**不能把它们降格为"可选进阶"**——这类钩子是 §8.2 与 §11 M2 的核心。

**属性型子类**：在 `on_apply` 里 `host.attributes.add_modifier(...)`，`on_remove` 里按 id/source 移除（与当前 `SlowBuff` 思路一致，但统一到 Buff 管线）。

**特殊型子类**：操作宿主上的 **状态机、输入组件、碰撞层、动画树** 等；**务必在 `on_remove` 还原**，避免残留。

### 8.1a `tick_interval`（每跳 vs 每帧）

`on_tick` 的调度由 **Def 上的字段**控制，不要让每个 Effect 自管累计器：

- `BuffDef.tick_interval: float`
  - **当前实现**：`0` = **不调度 `on_tick`**（只跟随 `remaining` 倒计时过期）；**`> 0`** = 每 N 秒调用一次 `on_tick`。
  - 如果以后需要"持续视觉/每帧推力"，推荐另加字段（例如 `tick_each_frame: bool`）或走新增的 `DotEffect`，**不要**把 `tick_interval == 0` 复用为"每帧"，以免破坏现有 Def。
- `BuffRuntime` 维护 `accumulated_time`，跨过阈值就调 `on_tick` 并扣减；漂移补偿可选。
- 首跳是否立即触发由 `tick_on_apply: bool` 决定。

### 8.1b 控制门控：引用计数（ControlFlags）

"眩晕/冰冻/沉默/缴械/定身" 这类门控**不能**在 `CombatantComponent` 上写 `is_silenced: bool`——多条 Buff 同时赋值会互相踩：A 先到期 `silenced = false` 时，B 的沉默就失效了。

统一改为**整型引用计数**：

```
CombatantComponent:
    silence_count: int
    disarm_count: int
    stun_count: int
    root_count: int
    pin_count: int        # 限位（九幽钉）
    untargetable_count: int   # 岚雾迷踪 / 夜伏

    var is_silenced: bool: get: return silence_count > 0
    var is_stunned:  bool: get: return stun_count > 0
    ...
```

对应的 Effect 子类在 `on_apply` 对计数 `+1`，`on_remove` 对计数 `-1`；**永远不要直接赋值 bool**。新加控制类型时，只需加一个 `_count` 字段和对应只读属性。

### 8.2 与伤害管线协作（核心，不是可选）

Buff 直接参与伤害改写（护盾吸收、单次免伤、易伤倍率、伤害转治疗等）。为避免每个 Buff 都去 patch `CombatantComponent`，统一走 **HitContext 管线钩子**：

- `modify_outgoing_damage(instance, host, hit)` — 出手侧（易伤/穿透快照）
- `modify_incoming_damage(instance, host, hit)` — 被打侧（减伤/护盾/免伤）

**调用顺序**必须在设计层锁死，否则"誓约庇护护盾 + 蝉蜕单次免伤 + 普通减伤"会出玄学结果：

```
DamagePhase:
    PreMitigation    # 易伤、穿透、流派加成
    Mitigation       # 护甲/抗性（通常由 CombatRules 本身做）
    PostMitigation   # 固定减伤、百分比减伤
    Absorb           # 护盾吸收、单次免伤（最后一步，吃"实际会造成的伤害"）
```

每条 Effect 声明 `damage_phase` 与 `priority: int`；`CombatantComponent` 在算伤害时按 `phase` 分段，同 phase 内 `priority` 降序调用。

### 8.3 `BuffDef` 资源里怎么表达 Effect

`BuffDef` 是 `.tres`，而 Effect 是代码逻辑——两者的绑定**统一采用"子资源 Def + 运行时实例"两层结构**：

```
BuffDef (Resource)
    id, tags, stacking_scope, refresh_policy, duration_policy, time_source,
    max_stacks, stack_scaling, mutex_group, priority, tick_interval, ...
    effects: Array[BuffEffectDef]        # 子资源数组

BuffEffectDef (Resource, 抽象基类)
    + AttributeEffectDef { stat_id, mode, value_or_per_stack, modifier_id_pattern }
    + ControlEffectDef   { control_type: Stun|Silence|Disarm|Root|Pin|Untargetable }
    + DamageHookEffectDef{ phase, priority, script_path, params }
    + DotEffectDef       { damage_type, base_per_tick, snapshot_keys, ... }
    + ScriptEffectDef    { script_path, params }   # 最后的万能出口

    func build_runtime(instance, host) -> IBuffEffect
```

编辑器里配 `.tres` 时只面对 `BuffEffectDef` 的子类，不接触具体的 `IBuffEffect` 运行时类——好调试、好序列化、好挂 inspector。

### 8.4 Snapshot 策略（DoT/HoT 的数值来源）

每个 `BuffDef` 必须显式声明**数值计算时机**：

| 策略 | 行为 |
|------|------|
| **SnapshotOnApply** | `apply` 时把 caster 的关键派生值（法强/暴击/穿透/标签加成）**拷入** `BuffInstance.snapshot: Dictionary`，以后每跳 DoT/HoT 都读快照。 |
| **Dynamic** | 每跳重新从 caster 读取；caster 失效（死亡/卸载）时按 fallback 策略处理——`UseSnapshot`（回落到首次快照）/ `StopTicking` / `ContinueWithZero`。 |
| **Hybrid** | 暴击/穿透快照，但 target 侧的易伤动态结算。 |

建议**默认 SnapshotOnApply**，`ApplyContext` 里存一份 `snapshot_keys` 让 Def 声明需要抓哪些字段，避免无脑拷整个属性表。

### 8.5 Tick 期间的增删安全（防连锁崩）

`BuffRuntime.tick` 内部**两阶段**执行，**严禁在遍历列表时直接增删**：

1. **Advance 阶段**：对每条实例调 `on_tick`、扣 `remaining` / `accumulated_time`，把到期的推入 `pending_expire`，新施加的 Buff 推入 `pending_apply`（允许 Effect 在 on_tick/on_damage_* 里施加新 Buff）。
2. **Flush 阶段**：统一调 `on_remove`、从主列表删除；再统一 apply `pending_apply`。

`on_remove` 中如果又想施加新 Buff（"A 到期时上 B"），同样走 `pending_apply`，避免迭代器失效与重入递归。

---

## 9. 参考其他游戏时的额外考量

| 维度 | 说明 |
|------|------|
| **优先级** | 已落到 `BuffDef.priority` 与 §8.2 `damage_phase + priority`（强断弱、控制覆盖、伤害改写顺序）。 |
| **快照（Snapshot）** | 见 §8.4：`SnapshotOnApply / Dynamic / Hybrid`，Def 字段显式声明。 |
| **同步顺序** | 见 §8.5 两阶段 tick；多 Buff 同时到期的 `on_remove` 调用顺序按 `priority` 降序。 |
| **资源与性能** | 大量小怪的 Buff 数量：对象池 `BuffInstance`；按 `tick_interval` 做分桶（每帧只更新到桶内实例），长时间无 tick 的 Buff 可休眠。 |
| **存档** | 见 §9.1 schema；`caster` 弱引用序列化时存持久化 id 而非 ObjectID。 |
| **联机**（若未来有） | 权威端施加、客户端预测图标；`ApplyResult` 天然适合 RPC 回放。 |
| **本地化与图标** | `BuffDef` 带 `display_name_key`、`description_key`、`icon`、`stack_text_format`。 |

### 9.1 存档 schema（建议尽早固化）

```
BuffInstance.serialize():
{
    def_id:            StringName,
    caster_persistent_id: String,  # 持久化 id（不是 ObjectID）
    remaining:         float,      # 仅 Timed 有效
    stacks:            int,
    snapshot:          Dictionary, # 仅 SnapshotOnApply/Hybrid 有值
    custom_state:      Dictionary, # 由 Effect.serialize() 供给
    source_skill_id:   StringName,
    source_tag:        StringName,
}
```

- `Effect` 可实现 `serialize() / deserialize(dict)`，用于保存非属性状态——例：护盾效果需要保存"已吸收 300/500"。没实现的 Effect 默认不贡献 `custom_state`。
- 只有 `save_policy = Persistent` 的 `BuffDef` 会被写入存档；战斗临时 Buff 默认 `save_policy = Transient`。

---

## 10. 与当前代码库的衔接

| 现有模块 | 衔接方式 |
|----------|----------|
| `StatModifier` / `CharacterAttributes` | 属性类 Effect **只负责增删 modifier**；时长仍可由 Buff 实例驱动，到期时统一 `on_remove`。Buff 运行时不再使用 `StatModifier.duration`——时间只由 Buff 管，modifier 视为"永久直到被移除"。 |
| `SlowBuff` | 逐步迁移到 `BuffDef + AttributeEffectDef`（见 §10.1 示例）。过渡期 `SlowBuff` 可保留为**内部工具**被 Effect 调用，但**新法术不再直接调用 `SlowBuff.apply`**，统一走 `BuffRuntime.apply`。 |
| `CombatantComponent` | 增加 `buffs: BuffRuntime` 引用；`died` 时通知 `BuffRuntime` 按 `BuffDeathPolicy` 清理。**tick 调用顺序必须固化**（见 §10.2）。当前实现挂在 `_process(delta)` 里调用 `tick(delta)`；如果以后改为 `_physics_process`，同顺序约束继续成立。 |
| 法术 / 技能 | 命中后构造 `ApplyContext`，调用 `target_combatant.buffs.apply(ctx)`；技能脚本**不再**直接 `add_modifier` / 直接调 `SlowBuff`。 |

### 10.1 `SlowBuff` 迁移示例

现有调用：
```
SlowBuff.apply(target, 3, 1.2, &"frost_trail")
```
等价于新管线：
```
target.buffs.apply(ApplyContext.new(
    def_id      = &"slow_lv3",
    caster      = self,
    source_tag  = &"frost_trail",
    duration    = 1.2,
))
```
其中 `BuffDef(slow_lv3)` 挂一个：
```
AttributeEffectDef {
    stat_id = MOVE_SPEED,
    mode    = PERCENT_ADD,
    value   = -0.30,
}
```
`stacking_scope = PerSourceSkill` 保留"同目标上 frost_trail / bramble_cage 各占一槽、不同来源独立合算"的原语义；`refresh_policy = KeepLonger`。

可选的优化：把 `LEVEL_TO_PCT` 从 `SlowBuff` 上移到 Def：只定义一个 `slow` Def，`stack_scaling = Table(LEVEL_TO_PCT)`，`StackRule = StackCount`，外部传层数即可，不再需要 `slow_lv1 ~ slow_lv10` 十份 Def。

### 10.2 tick 调用顺序

> 当前代码里挂在 `_process(delta)`（`CombatantComponent._process` → `tick(delta)`）。顺序约束与挂哪个进程回调无关。

```
CombatantComponent.tick(delta):
    1. buffs.tick(delta)
       ├─ on_tick / 到期的属性 Effect 在 on_remove 中 remove_modifier → 属性 dirty
       └─ pending_apply flush（可能再 add_modifier）
    2. attributes.tick(delta)
       └─ 重算 final_stats / derived_stats（此时反映 Buff 变更）
    3. HP / MP 回复、垃圾回收等
    4. 进入 AI / 移动 / 伤害结算阶段（读到的都是最新数值）
```

**关键不变量**：同一帧内，伤害结算时读取的属性 = 已经把当帧到期 Buff 移除后的属性。避免"这一帧 Buff 已过期但属性还是加成版"之类 bug。

---

## 11. 建议的最小实现路线（里程碑）

0. **M0（验证管线，最小替换）**：仅实现 `BuffDef` + `BuffInstance` + `BuffRuntime(apply/remove/tick)`，把 `SlowBuff` **一条路径**替换掉（§10.1），确保新旧数值一致。目的是跑通 Def → Effect → StatModifier 的闭环，避免新旧两套并存跨多个迭代。
1. **M1**：通用 **AttributeEffect**（多属性、PERCENT_ADD/FLAT/PERCENT_MULT）+ `ApplyResult` + `RefreshPolicy` + `StackingScope`。此阶段就要上 `ApplyResult`，调用方一旦习惯就难回退。
2. **M2**：**伤害管线钩子**（`modify_incoming/outgoing_damage` + `phase + priority`）+ 互斥组 + 容量/优先级驱逐 + 免疫标签。这是 ARPG 技能落地的关键里程碑（誓约庇护、蝉蜕、血印等都要它）。
3. **M3**：**控制门控（ControlFlags 引用计数）** + `ScriptEffect` / GDScript 回调，接入沉默/眩晕/定身/限位；触发型钩子（`on_damage_taken / on_damage_dealt / on_kill`）。
4. **M4**：UI 图标列表（排序约定见 §6.3）+ 驱散技能扫描 `dispellable` 标签 + Snapshot/序列化（§8.4 + §9.1）。
5. **M5（选配）**：性能优化（对象池、tick 分桶）、存档读写、联机扩展点。

---

## 12. 小结

- **整体 Buff 系统** = **Buff 运行时（实例管理、时间、死亡策略、两阶段 tick）** + **效果列表（属性走 StatModifier、控制走 ControlFlags 计数、伤害走 phase+priority 钩子、其他走 Script）** + **标签（驱散/免疫/容量）**。
- **玩家与怪物** 无第二套接口：一律 **`CombatantComponent` + `BuffRuntime`**，差异仅在 **Def 与是否免疫某类标签**。
- **施加入口唯一**：`BuffRuntime.apply(ApplyContext) -> ApplyResult`；技能脚本不再自己 `add_modifier` 或调 `SlowBuff.apply`。
- **落地前必须钉死的关键枚举 / 字段清单**（集中在此处备查）：
  1. `ApplyResultKind`（§6.4）
  2. `BuffRefreshPolicy`（§5.3）
  3. `BuffStackingScope`（§5.2）
  4. `tick_interval` + `tick_on_apply`（§8.1a）
  5. `ControlFlags 引用计数`（§8.1b）
  6. `DamagePhase + priority`（§8.2）
  7. `BuffEffectDef` 子资源体系（§8.3）
  8. `Snapshot policy` + `snapshot_keys`（§8.4）
  9. 两阶段 tick 安全协议（§8.5）
  10. `_physics_process` 调用顺序（§10.2）
- 当前工程已有 **`StatModifier` 时间驱动** 与 **`SlowBuff` 样板**；新系统应 **收拢施加入口**，并为 **非属性效果** 预留 **on_apply / on_remove / on_tick / on_damage_* / on_kill**，避免长期散落在各技能脚本里。

---

## 13. 相关文档

- `./战斗与属性统一体系.md`（若存在属性 id 约定，与 AttributeEffect 对齐）  
- `./法术系统设计记录.md`  
- `scripts/core/attributes/stat_modifier.gd`、`character_attributes.gd`  
