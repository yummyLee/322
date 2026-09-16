# UI 窗口拖拽与层级管理设计记录

## 文档目的
- 说明所有 UI 面板窗口的鼠标拖拽与点击置顶功能的实现方式。
- 为后续新增面板窗口提供接入指南。

---

## 1. 功能范围

所有 CanvasLayer 面板窗口均已支持：
- **标题栏拖拽**：鼠标按住标题文字拖动整个面板，自动限制在屏幕边界内
- **点击置顶**：点击面板任意位置将其提升到所有 UI 最上层
- **打开自动置顶**：通过快捷键打开面板时自动跳到最上层

涉及的 6 个面板：

| 面板 | 文件 | 快捷键 | 标题栏 |
|---|---|---|---|
| 背包 | `scripts/ui/inventory_ui.gd` | B | "背  包" |
| 武器选择 | `scripts/ui/debug_weapon_menu.gd` | I | "── 调试：武器选择 ──" |
| 场景跳转 | `scripts/ui/debug_stage_menu.gd` | U | "── 调试：场景跳转 …" |
| 经验兑换 | `scripts/ui/experience_purchase_ui.gd` | E | "经验兑换" |
| 角色属性 | `scripts/ui/player_stats_panel.gd` | P | "角色属性" |
| 技能面板 | `scripts/ui/skill_panel.gd` | K | "技能面板（…）" |

以下 HUD 元素保持固定位置，不支持拖拽：
- HP 显示（`player_hp_hud.gd`）
- Buff 条（`player_buff_strip.gd`）
- 技能热键栏（`spell_hotbar.gd`）

---

## 2. 架构

### 2.1 核心组件

```
scripts/ui/
├── ui_drag_handler.gd      # 通用拖拽组件（class_name UIDragHandler）
├── ui_layer_manager.gd     # 层级管理器（autoload UILayerManager）
```

### 2.2 UIDragHandler

`class_name UIDragHandler extends Node`

通用拖拽组件，将指定句柄的鼠标拖拽映射为目标的位移。

```gdscript
# 用法
var dh := UIDragHandler.new()
add_child(dh)
dh.setup(handle, target)          # handle=拖拽触发区，target=被移动的面板
dh.setup(handle, target, false)   # 第三个参数 false = 不限制屏幕边界
```

**内部逻辑：**
- 通过 `gui_input` 信号监听手柄的鼠标按下/移动
- 拖拽中持续更新 `target.global_position`
- 默认启用屏幕边界钳制（`_clamp_position`），防止拖出屏幕

### 2.3 UILayerManager

`extends Node`（自动加载单例，名称 `UILayerManager`）

使用递增的 `layer` 值管理 CanvasLayer 的显示层级。

```gdscript
# 将面板提升到最上层
UILayerManager.bring_to_front(canvas_layer)

# 检查鼠标是否在控件区域内（静态方法）
UILayerManager.is_mouse_inside_control(control) -> bool
```

**层级策略：**
- 从 `layer = 100` 开始，每次调用 `bring_to_front` 递增 1
- 各面板原始的固定 `layer` 值仅决定初始堆叠顺序，点击后被动态覆盖
- 所有面板方法均为 `static`，无需实例即可调用

---

## 3. 接入方式（给后续开发）

### 3.1 为新面板添加拖拽和置顶

假设新面板的 CanvasLayer 脚本中已有 `_panel` 作为面板容器，标题为 `title` Label：

**步骤 1：使标题可拖拽**

在 `_build_ui()` 或 `_ready()` 中，标题创建后添加：

```gdscript
title.mouse_filter = Control.MOUSE_FILTER_STOP   # 让 Label 接收鼠标事件
var dh := UIDragHandler.new()
add_child(dh)
dh.setup(title, _panel)   # 拖拽标题 → 移动 _panel
```

**步骤 2：添加点击置顶**

```gdscript
func _input(event: InputEvent) -> void:
    if _panel == null or not _panel.is_visible_in_tree():
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if UILayerManager.is_mouse_inside_control(_panel):
            UILayerManager.bring_to_front(self)
```

**步骤 3：打开时自动置顶**

在面板变为可见的代码位置（`show()` 或 `_panel.visible = true` 之后）添加：

```gdscript
UILayerManager.bring_to_front(self)
```

### 3.2 注意事项

- 标题 Label 必须设置 `mouse_filter = Control.MOUSE_FILTER_STOP`，否则不接收鼠标事件
- 面板变量必须是成员变量（`var _panel: Panel`），不能在 `_build_ui()` 中声明为局部变量，否则 `_input()` 无法访问
- `_input()` 中使用 `is_visible_in_tree()` 而非 `visible`，因为部分面板隐藏的是内部 `_panel` 而非 CanvasLayer 本身
- `UILayerManager` 的所有方法均为静态，直接通过 `UILayerManager.xxx()` 调用

---

## 4. 关键文件清单

| 文件 | 说明 |
|---|---|
| `scripts/ui/ui_drag_handler.gd` | 拖拽组件 |
| `scripts/ui/ui_layer_manager.gd` | 层级管理器 autoload |
| `scripts/ui/inventory_ui.gd` | 背包面板，拖拽标题 + 点击/B键打开置顶 |
| `scripts/ui/debug_weapon_menu.gd` | 武器选择面板，Title 节点来自 .tscn |
| `scripts/ui/debug_stage_menu.gd` | 场景跳转面板，Title 节点来自 .tscn |
| `scripts/ui/experience_purchase_ui.gd` | 经验兑换面板 |
| `scripts/ui/player_stats_panel.gd` | 角色属性面板，panel 改为 `_panel` 成员变量 |
| `scripts/ui/skill_panel.gd` | 技能面板（PanelContainer） |
| `project.godot` | `[autoload]` 中注册 `UILayerManager` |

---

## 5. 已知限制

- 拖拽后面板的位置在窗口大小改变后会重置（因为 offset 基于 CENTER 锚点）
- 层级计数器从 100 开始无限递增，虽然 int 范围足够大，但理论上长期运行会溢出
- 未对 HUD 类元素（HP、Buff、热键栏）做拖拽支持，它们固定在预设位置
