# 行旅者 02 · 骨骼蒙皮版 / 八方向显示

中国古代布衣风格的可编辑角色。采用更接近人体的头身比例、收窄的头肩、曲面躯干与四肢、手掌与分指、独立服装和发型。仍是风格化模型，并非扫描级写实人体。

## 运行与检查

项目入口 `res://hero_v2/main.tscn`，按 F5。

| 按键 | 功能 |
| --- | --- |
| 方向键 / Shift | 行走 / 按住跑步；视觉朝向锁定为 8 个方向 |
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
| `character_stage.tscn` | 独立透明人物层：人物实例、固定灯光、环境和同步相机 |

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

AnimationPlayer 保存 `RESET`、`idle`、`walk`、`run`。待机有轻微呼吸；走跑包含脚跟落地、脚掌过渡、脚尖离地、骨盆微摆、上身前倾、反向摆臂、屈肘、髋膝和踝部动作。主动画有 0.16 秒姿态混合，人物移动和朝向在下一次物理更新直接响应，不采用转向渐变或移动惯性。

显示朝向不再连续旋转。控制器把屏幕移动方向量化到 8 个方向（每 45°），只更新 Visual 的离散角度；CharacterBody3D 的碰撞体和世界位移保持原方向，不会因为转身旋转碰撞体。这样能显著减少 3 渲 2 中连续旋转造成的轮廓重采样和模糊跳动。方向接近分界线时会跳到相邻方向，这是八方向方案的预期表现。

SecondaryMotion 驱动专用辅助骨骼：

- `HemFrontL/R`、`HemBackL/R`：衣摆跟随迈步，并有少量延迟回摆。
- `CuffL/R`：袖口轻微形变。
- `SashTail`：布带尾端随加减速和转向摆动。
- `HairFrontL/R`、`HairSideL/R`、`HairTail`：发梢轻微随动，发根和发帽保持稳定。

这是带阻尼的辅助骨骼动画，并非带自碰撞的布料或毛发物理模拟。停步后会回稳。

Inspector 参数：`enabled` 开关；`strength` 强度（0.75）；`stiffness` 恢复力度（85）；`damping` 衰减（16）。主动画不写辅助骨骼，避免覆盖随动结果。

## 镜头与像素稳定

人物直立。默认正交镜头俯视约 29°、水平偏转约 21°，可视高度 7 米。

稳定模式以人物插值位置为基准量化相机偏移，减少人物和相机采样不同步导致的闪动。人物层保留阴影修复前的采样方式：宽高各两倍渲染，每个逻辑像素使用四个空间采样后整数放大；环境层使用相同采样设置。两层分别采样各自的纹理，使用独立滤镜材质，均没有 MSAA、TAA 或历史帧混合。B 切换相机稳定与两层的采样模式；真实投影的修复不改变人物的采样和滤镜效果。

### 人物独立显示，真实阴影留在环境中

- `EnvironmentViewport/EnvironmentWorld/Traveler` 是唯一运行移动、碰撞、主动画和衣发随动的实例。其网格在合成场景运行时设为 `SHADOWS_ONLY`：不显示主体颜色，但仍向庭院地面和其他接收面投射真正的模型阴影。没有矩形或椭圆阴影片；投影随动作、服装、太阳方向变化。
- `CharacterViewport/CharacterWorld` 使用单独保存的 `character_stage.tscn`，只包含人物、固定灯光、环境和相机。每个物理更新在动作和随动完成后同步位置、朝向、骨骼姿态及衣发显隐；不重复运行控制器或动画。
- 两个 Viewport 使用独立 World3D；人物照明不受庭院环境色和太阳变化影响。人物相机在世界跟随相机更新后复制最终参数，避免一帧滞后。
- 世界、角色、灯光和相机均为可编辑的保存节点。独立打开 `world.tscn` 仍可以看到完整人物，`main.tscn` 负责运行时的分层显示。

两层通过 GPU 深度比较保留真实前后遮挡：`depth_capture.gd` 从两台相机的当前帧各复制一张 R32F 深度纹理，`pixel_resolve.gdshader` 在原有采样位置逐点比较距离，剔除被前景物体挡住的人物样本，再执行原有四点采样和整数放大。人物颜色、材质、灯光与采样设置保持不变；真实阴影仍在环境层。

遮挡使用环境的实际渲染网格，不依赖物体碰撞盒、手工排序或额外遮挡替身。当前不透明庭院物体支持完整和局部遮挡；后续玻璃、烟雾等不写入深度的透明材质需要专门处理。此实现使用项目已有的 Forward+ 渲染器，不支持 Compatibility。窗口缩放或 P/B 切换会重新配置深度纹理，不读取 CPU 图像，也不使用历史帧。

两个 Compositor 资源保存在 `main.tscn` 的根节点导出属性中，分别绑定世界和人物相机。深度比较采用相同投影下的 reverse-Z 值，偏差为 0.00002（默认正交镜头约 2 毫米），避免接触面精度误差。[Godot Compositor 官方说明](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)。

正常动作、衣发形变和背景滚动仍会改变像素边缘，不能保证完全无闪动；8 方向方案会用 45° 离散转向替代连续转向。

相关资料：[Godot 骨骼蒙皮关联](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-property-skeleton)、[相机物理插值](https://docs.godotengine.org/en/4.4/tutorials/physics/interpolation/advanced_physics_interpolation.html)。

## 放入目标世界

将 traveler.tscn 拖入带地面碰撞的世界，设置 `movement_camera`。如需本版跟随镜头，复制 world 中的 FollowCamera，并设置 target。脚底为原点，本地 +Z 为正面。根节点的 `walk_speed`、`run_speed` 控制速度。

## 制作和验证

日常直接编辑保存的场景。`tools/refine_skinned_character.gd` 是本次使用的一次性作者工具，要求 `--bake --overwrite`；重跑会覆盖模型和动作编辑。较早的 build_traveler 和 revise_ancient_costume 是历史工具，不应用来刷新当前版本。

`tools/verify_traveler.gd` 验证骨架、全部蒙皮权重与绑定、人体比例、走跑步态、8 方向立即转向、衣发随动与停步回稳、换装、碰撞和镜头控制。`tools/verify_pixel_stability.gd` 使用 GPU 检查固定姿态平移的轮廓稳定性。`tools/verify_render_layers.gd` 使用 GPU 对比真实投影开关、人物透明边缘、环境光独立性，以及两层相机、动作和换装同步。`tools/verify_occlusion.gd` 验证高墙全遮挡、矮墙局部遮挡、人物在前时原样显示，以及 P/B、相机旋转和分辨率变化后的遮挡；专用测试墙保存在 `tools/occlusion_fixture.tscn`，不加入游戏场景。

preview 中有实际渲染截图：08_model_detail（原始 3D 近景）、09_indigo_outfit（靛青装）、10_anatomy_study（基础人体），以及像素视图和走跑截图。日志只留在本机，不纳入 Git。
