# 乱葬岭左山洞

依据 `E:/GameDev/openworldtest/resources/map/architecture乱葬岭左山洞/乱葬岭左山洞.png` 制作的独立 Godot 4.x 3D 场景。场景沿用窑村的正交镜头、低多边形构件、三阶材质、像素采样与轮廓描边，所有洞壁、阶梯水池、瀑布、尸骨、钟乳石、矿车、木架、桥板、灯光和碰撞均保存为可编辑节点。

- 编辑入口：`res://burial_left_cave/world.tscn`
- 运行入口：`res://burial_left_cave/main.tscn`
- 游戏默认入口保持：`res://village/main.tscn`
- 乱葬岭根缠石门 `RootWrappedStoneGate/ReservedEntrance` 已连接到本场景；进入目标出生点为 `root_cave_entry`。
- 洞内 `EntranceTransition/ExitToNorthernRidge` 返回 `res://village/main.tscn` 的 `root_cave_exit` 出生点。

布局按参考图的主要空间关系做了低多边形近似：左侧冷色阶梯水池与瀑布、中央尸骨散落区、右侧木架/矿车工作区、下层水潭和钟乳石、后方黑暗通道。手绘裂纹、骨骼细节与水体体积光未按单张图逐像素复刻。

制作脚本仅用于离线烘焙：`tools/build_scene.gd`。日常编辑应直接修改已保存的 `world.tscn`，不要重复运行烘焙脚本覆盖编辑器修改。
