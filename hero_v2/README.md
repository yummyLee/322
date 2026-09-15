# 行旅者 02 · 骨骼蒙皮版

中国古代布衣风格的可编辑角色。采用更接近人体的头身比例、收窄的头肩、曲面躯干与四肢、手掌与分指、独立服装和发型。仍是风格化模型，并非扫描级写实人体。

## 运行与检查

项目入口 `res://hero_v2/main.tscn`，按 F5。

| 按键 | 功能 |
| --- | --- |
| 方向键 / Shift | 行走 / 按住跑步 |
| Q、E / 滚轮 | 旋转镜头 / 缩放 |
| F | 近景（2.8 米）/ 世界视野 |
| P | 像素画面 / 原始 3D |
| B | 稳定像素 / 旧方案对比 |
| C | 麻布短袍 → 靛青配色短袍 → 基础人体 |
| H | 显示 / 隐藏头发 |
| R | 重置镜头 |

F + P 适合检查曲面、手指和衣料。C 切到基础人体后，H 可查看独立头型。基础人体保留中性底裤。

## 文件和可编辑结构

| 文件 | 内容 |
| --- | --- |
| `traveler.tscn` | 完整人物装配、碰撞、控制器、主动画和随动 |
| `model/body_rig.tscn` | Skeleton3D 的 31 根骨骼、人体、五官和手指 |
| `outfits/linen_robe.tscn` | 独立麻布短袍、袖子、衣摆、裤子、绑腿、鞋 |
| `outfits/indigo_robe.tscn` | 同款短袍的独立靛青配色换装示例 |
| `hair/tied_hair.tscn` | 独立发帽、发髻、发簪和可弯曲的发束 |
| `model/traveler_editable.glb` | 可用 Blender 等软件编辑的网格、蒙皮、骨架和四组动画；含人体、麻布装、头发 |
| `world.tscn` / `main.tscn` | 保存的庭院 / 像素显示与界面 |

Godot 中可编辑网格节点、材质、骨骼、动画和场景结构。要修改顶点、拓扑或雕刻形体，使用 GLB 在 Blender 等软件中修改。GLB 使用通用材质，Godot 中的像素效果由项目着色器实现。

单套完整装配共有 **54 个网格、10,096 个顶点、17,164 个三角面**。人体、服装和头发均为独立几何。四肢使用跨关节的蒙皮权重，弯曲时周围网格连续变形。

```text
Traveler (CharacterBody3D)
├─ BodyCollision
├─ Facing
│  └─ Visual (wardrobe.gd)
│     ├─ Rig          ← body_rig.tscn，骨架与人体
│     ├─ LinenRobe    ← linen_robe.tscn
│     ├─ IndigoRobe   ← indigo_robe.tscn，默认隐藏
│     └─ Hair         ← tied_hair.tscn
├─ AnimationPlayer
└─ SecondaryMotion
```

这些节点全部保存于场景中，运行时不创建网格或重建场景。

## 更换衣服和发型

1. 打开服装场景并另存为，独立修改网格和材质。
2. 将新衣服场景放到完整人物的 `Facing/Visual` 下，保持实例 Transform 为单位变换。
3. 服装 Mesh 的 `skeleton` 指向 `../../Rig`；沿用同一骨架、静止姿态和 Skin 绑定，不要重排骨骼索引。
4. 选择 Visual，将新服装节点路径添加到 Inspector 的 `outfit_nodes`。C 会自动纳入该衣服；最后一项为基础人体。
5. `outfit` 设置默认服装序号，`show_hair` 设置头发显隐。替换 Hair 实例即可换发型。

独立打开服装场景可编辑静止网格，在完整人物场景中预览蒙皮。服装与身体预留间隙；大幅修改身材、衣型或动作后，仍需检查穿插并调整权重。

## 动作与轻微随动

AnimationPlayer 保存 `RESET`、`idle`、`walk`、`run`。待机有轻微呼吸；走跑包含摆臂、屈肘、髋膝和踝部动作。主动画有 0.16 秒姿态混合，人物朝向和移动方向在下一次物理更新直接响应，不采用转向渐变或移动惯性。

SecondaryMotion 驱动专用辅助骨骼：

- `HemFrontL/R`、`HemBackL/R`：衣摆跟随迈步，并有少量延迟回摆。
- `CuffL/R`：袖口轻微形变。
- `SashTail`：布带尾端随加减速和转向摆动。
- `HairFrontL/R`、`HairSideL/R`、`HairTail`：发梢轻微随动，发根和发帽保持稳定。

这是带阻尼的辅助骨骼动画，并非带自碰撞的布料或毛发物理模拟。停步后会回稳。

Inspector 参数：`enabled` 开关；`strength` 强度（0.75）；`stiffness` 恢复力度（85）；`damping` 衰减（16）。主动画不写辅助骨骼，避免覆盖随动结果。

## 镜头与像素稳定

人物直立。默认正交镜头俯视约 29°、水平偏转约 21°，可视高度 7 米。

稳定模式以人物插值位置为基准量化相机偏移，减少人物和相机采样不同步导致的闪动。每个逻辑像素使用四个空间采样后整数放大，没有 MSAA、TAA 或历史帧混合；渲染像素数约为旧方案四倍。B 可比较新旧模式。

正常动作、衣发形变、转身和背景滚动仍会改变像素边缘，不能保证完全无闪动。

相关资料：[Godot 骨骼蒙皮关联](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-property-skeleton)、[相机物理插值](https://docs.godotengine.org/en/4.4/tutorials/physics/interpolation/advanced_physics_interpolation.html)。

## 放入目标世界

将 traveler.tscn 拖入带地面碰撞的世界，设置 `movement_camera`。如需本版跟随镜头，复制 world 中的 FollowCamera，并设置 target。脚底为原点，本地 +Z 为正面。根节点的 `walk_speed`、`run_speed` 控制速度。

## 制作和验证

日常直接编辑保存的场景。`tools/refine_skinned_character.gd` 是本次使用的一次性作者工具，要求 `--bake --overwrite`；重跑会覆盖模型和动作编辑。较早的 build_traveler 和 revise_ancient_costume 是历史工具，不应用来刷新当前版本。

`tools/verify_traveler.gd` 验证骨架、全部蒙皮权重与绑定、人体比例、走跑与转向、衣发随动与停步回稳、换装、碰撞和镜头控制。`tools/verify_pixel_stability.gd` 使用 GPU 检查固定姿态平移的轮廓稳定性。

preview 中有实际渲染截图：08_model_detail（原始 3D 近景）、09_indigo_outfit（靛青装）、10_anatomy_study（基础人体），以及像素视图和走跑截图。日志只留在本机，不纳入 Git。
