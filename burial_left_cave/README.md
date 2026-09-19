# 乱葬岭左山洞

依据 `E:/GameDev/openworldtest/resources/map/architecture乱葬岭左山洞/乱葬岭左山洞.png` 与场景描述文档重建的独立 Godot 4.x 3D v4 场景。场景沿用窑村的正交镜头、低多边形构件、三阶材质、像素采样与轮廓描边，核心布局是贴近参考图的 14 个洞室、连续弯曲通路、三条回路、两条捷径和黑色裂谷；所有洞壁、石柱、水池、瀑布、尸骨、钟乳石、矿车、木架、桥板、灯光和碰撞均保存为可编辑节点。

- 编辑入口：`res://burial_left_cave/world.tscn`
- 运行入口：`res://burial_left_cave/main.tscn`
- 游戏默认入口保持：`res://village/main.tscn`
- 乱葬岭根缠石门 `RootWrappedStoneGate/ReservedEntrance` 已连接到本场景；进入目标出生点为 `root_cave_entry`。
- 洞内 `EntranceTransition/ExitToNorthernRidge` 返回 `res://village/main.tscn` 的 `root_cave_exit` 出生点。

布局按参考图和 J0～J13 场景描述重建为直接世界坐标：南侧 J0 入口，中央 J8 旧车场，左侧 J3/J9 湿路与石柱林，西北 J6 竖井，北侧 J5 码骨厅和 J10 灰瀑阶地，东侧 J11 悬骨桥、J12 采石廊和 J13 记名壁室。所有可行走区块和主通路统一在 `Y=0` 基准面；洞壁向下挤出形成厚度，只有瀑布阶、深井、桥栏和钟乳石使用额外高度。每个区块都是独立的不规则地面与连续洞壁，区块之间用共享端点的窄通路连接，黑色裂谷保持为空。地图外缘和行走面都使用已保存的 `StaticBody3D` 碰撞，角色出生时会站在地面上，不会从悬空块或场景缝隙掉落。完整的区块拆分与路线设计见 `ZONE_DESIGN.md`。

制作脚本仅用于离线烘焙：`tools/build_scene.gd`。日常编辑应直接修改已保存的 `world.tscn`，不要重复运行烘焙脚本覆盖编辑器修改。
