# 乱葬岭北侧林地

依据 `openworldtest/resources/map/Backup/地图草稿乙.png`，在现有乱葬岭北面、窑村西北面继续扩建。参考图下方的墓地、石龛、推车与守墓人茅屋属于已有区域，保留原物件作为衔接锚点。

## 编辑与运行

- 总场景：`res://village/yao_village.tscn`，新增可展开编辑的 `NorthernRidge` 子场景。
- 独立编辑：`res://northern_ridge/world.tscn`。所有地形、道路、树木、建筑、装饰与碰撞都是已保存节点；运行时不生成或覆盖布局。
- 运行入口仍为 `res://village/main.tscn`。保留原玩家、出生点、相机和设置菜单。
- 制作前工作区干净，原状态回退点为 `e415e2d`。此次没有重新生成窑村或旧墓地。

| 节点 | 位置 X / Z | 内容 |
| --- | --- | --- |
| RootWrappedStoneGate | -55 / -48 | 石门、根缠土丘、两侧松树、可进出的门洞 |
| WeatheredWaysidePavilion | -63 / -36.5 | 四柱旧路亭、瓦顶、褪色木牌、石供台 |
| DampHerbHollow | -72 / -42 | 苔土浅洼、野生药草、旧木柄铁铲 |
| AncientRootTree | -77 / -68 | 古树、放射分叉树根与不规则树冠 |
| BrokenRedSlopeTerraces | 西北红土坡 | 断续碎石坡坎、散石、旧警示石 |
| MixedNorthernForest | 北侧与两边 | 深绿/枯黄针叶树及沿用窑村风格的阔叶树 |
| MidgroundUnderstory | 道路与地标之间 | 低矮灌木簇、半埋碎石、倒枝与断梢，填充中景留白并保持路线视线 |
| WindingTrails | 五组道路 | 墓地至路亭、石门支路、东侧林道、北侧横路、红土上坡路 |

新地形范围 X=-112…-26，Z=-82…-42；可行走边界延伸到 Z=-77，西界延续 X=-87。地形在 Z=-42 与旧地形对齐，过渡区向北逐渐增加缓坡和红土。石门北侧抬升和入口浅洼直接写入同一套地形高度函数，不叠加带明显边界的覆盖面。顶点 RGBA 保存草地、矿土、泥土、腐叶土权重；地面使用多尺度色差、柔边苔斑、成簇杂草、叶屑与半埋石，中央空地另有低矮灌木簇、零散石窝和倒枝分层，避免纯色地板和大块空白。

旧墓地北界碰撞已开放；东侧连接处移动六棵旧树及对应树干碰撞。道路沿实际地面起伏铺设，有不规则路肩、磨损、浅车辙、碎石和断续铺石。根缠石门采用北高南低的连续地形，洞口两侧为缓坡折面，根系逐点贴合地形高度。门洞按 1.86 单位高的实际玩家校准，约 1.64 单位净宽；洞内地板至顶面净高约 2.23 单位。

## 预留洞室入口

`RootWrappedStoneGate/ReservedEntrance` 保存 `door_link_id=northern_root_cave_door`、`destination_id=northern_root_cave`，现在已连接到 `res://burial_left_cave/main.tscn`，监测开启，目标出生点为 `root_cave_entry`。`EntryPoint` 和 `ExitSpawn` 分别保存进洞与返回位置；洞内场景的出口会回到 `res://village/main.tscn` 的 `root_cave_exit`。

洞顶和侧壁现已嵌入保存的连续坡体，坡面只在入口前脸开口，洞顶上方保留土层；入口短缓坡连接低处道路和洞内地板。局部离线修改记录为 `tools/embed_saved_cave.gd`，默认读取已保存场景并带重复执行保护，不依赖运行时生成。树木、根段、地表装饰及碰撞已随局部高程调整。

## 验证

最新洞口检查：2026-09-19，Godot 4.7.2、D3D12 Forward+、RTX 5080。

- `tools/validate.gd`：原入口集成、实际节点归属、183 个新旧边缘顶点的高度/权重连续、55 处地形碰撞采样、四条实际玩家通行测试（含石门往返）、洞顶覆土和通道身体/头部净空、编辑后的磁盘保存重载。
- `tools/verify_gpu.gd`：通过原入口加载场景，检查原出生点、分阶光照开关、整数像素缩放、菜单暂停与恢复；输出并人工查看像素、普通 3D、近景和缓坡截图，洞口额外检查正面、侧面及背面。
- 回归 `burial_ridge/tools/validate.gd`、`validate_terrain.gd` 与 `village/tools/validate_lived_in.gd`，保留村西连接、旧墓地地形、北院和旧墓室/石祠入口通行。

场景是参考图布局和视觉要素的低多边形近似，细小刻痕、根须、草叶有所简化。主路、树干和入口有碰撞；草叶、小碎石、根须及土丘装饰面没有逐面行走碰撞。测试覆盖指定通路，不代表所有装饰区域可通行。

日常直接修改保存的场景；移动地形和主要物体时同步调整碰撞。修改共享材质或网格前按需要将资源唯一化。`tools/extend_north.gd` 是本轮离线制作留档，重新烘焙会覆盖新区手动修改，不作为运行依赖。`integrate_north.gd` 和 `link_saved_scene.py` 已应用，有重复执行保护。不要重跑原 `village/tools/build_village.gd`。
