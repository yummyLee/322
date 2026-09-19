# 乱葬岭左山洞

依据 `E:/GameDev/openworldtest/resources/map/architecture乱葬岭左山洞/乱葬岭左山洞.png` 制作的独立 Godot 4.x 3D 场景。场景沿用窑村的正交镜头、低多边形构件、三阶材质、像素采样与轮廓描边，核心布局是黑色虚空中的多块高低平台、窄路、分岔和断桥，所有洞壁、阶梯水池、瀑布、尸骨、钟乳石、矿车、木架、桥板、灯光和碰撞均保存为可编辑节点。

- 编辑入口：`res://burial_left_cave/world.tscn`
- 运行入口：`res://burial_left_cave/main.tscn`
- 游戏默认入口保持：`res://village/main.tscn`
- 乱葬岭根缠石门 `RootWrappedStoneGate/ReservedEntrance` 已连接到本场景；进入目标出生点为 `root_cave_entry`。
- 洞内 `EntranceTransition/ExitToNorthernRidge` 返回 `res://village/main.tscn` 的 `root_cave_exit` 出生点。

布局按参考图和 J0～J13 场景描述做了低多边形近似：左上冷色阶梯水池与瀑布、中央高台尸骨区、右上木架/矿车工作区、左下钟乳石水潭、右下墓台、中央桥梁和后方黑暗通道，并补出石柱林、陷坑井、北侧码骨厅、采石廊和记名壁室。整体布局横纵向放大到 2.8 倍；各区域以长弯路、窄桥和高低错落的落脚平台连接，平台外保持黑色落差。地图外缘有不可见边界墙，底部有安全接住面，避免角色掉出场景。补充了骨架陈列架、悬挂绳索、矿区箱具、斧镐、墓碑、桥栏、后洞祭台、石灰罐、运尸车、记名牌和洞壁苔藓。手绘裂纹、骨骼细节与水体体积光未按单张图逐像素复刻。

制作脚本仅用于离线烘焙：`tools/build_scene.gd`。日常编辑应直接修改已保存的 `world.tscn`，不要重复运行烘焙脚本覆盖编辑器修改。
