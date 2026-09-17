# 窑村西侧：乱葬岭

按 `乱葬岭左1完全.png` 在原村庄西侧扩展，运行入口仍是 `res://village/main.tscn`。

## 编辑

- 整体编辑：`village/yao_village.tscn` → `WesternBurialRidge`（已启用可编辑子节点）。
- 新区单独编辑：`burial_ridge/world.tscn`。选择任意地标后按 F 聚焦；所有模型和碰撞均为已保存的真实节点。
- `TerrainAndPaths`：冷灰墓地地表、林间土路、岔路与村庄连接道路。
- `Graveyard`：22 处普通墓碑、一座高碑、石龛、残墓、废弃推车和木标。
- `BareRidgeTrees`：10 棵可单独调整的枯树；`LivingForest`：林缘树群。
- `ForestHomesteads`：两座茅屋、晾架、陶罐、柴堆及院落道具。
- `BrokenRockTerraces` / `MeadowAndGroundDetails`：断石坡、芦草与地面细节。
- `SavedWalkCollisions`：地面、房屋、树干、墓碑及外围边界碰撞。

新区沿 X 负方向展开，主路从原村西边约 `(-23, 0, 7)` 向左接入。沿村西菜地外围土路穿过林间缺口即可进入。保留原出生点、原村建筑和默认镜头。只移动了挡住接口的六棵旧树，并同步移动树干碰撞；原 X=-40 的边界碰撞已禁用，新西边界为 X=-87。

共享材质直接使用 `village/style.gdshader`，沿用当前窑村的分阶光照和独立人物像素合成。没有另建运行时渲染系统。单独调整共享网格/材质时，先将相应资源唯一化。

## 验证与截图

本次验证：Godot 4.7.2 / D3D12 Forward+ / RTX 5080。静态场景与通行检查 `failures=0`；GPU 和原菜单检查 `failures=0`。新区共 8,541 个保存节点，其中 7,477 个为真实 MeshInstance3D。通行验证覆盖村西接口到墓地的九段连续主路，不代表所有装饰区域均可通行。

- `tools/validate.gd`：保存节点/归属、地标、磁盘编辑重载、原入口集成、旧树碰撞同步，以及使用真实角色碰撞体从村西通路连续走到墓地。
- `tools/verify_gpu.gd`：加载原 `village/main.tscn`，检查原出生点、设置开关、像素网格同步，并输出实际 D3D12 Forward+ 截图。
- `preview_overview.png`：新区全景；`preview_joined.png`：新区与原窑村同框；`preview_detail.png`：墓地区域；`preview_seam.png`：连接处；`preview_plain.png`：非像素对照；`preview_settings.png`：原设置菜单。
- 截图工具只临时调整查看位置，不修改保存的相机或出生点。

地形按参考图的分区、道路与地标关系做了几何化近似；不是逐像素复刻。墓碑字痕为抽象磨蚀刻痕，图中的手绘裂纹、草叶和土坡高差进行了简化。主路和主要障碍有碰撞，小碎石、草丛及部分装饰石坡没有精细碰撞。

`tools/build_scene.gd` 仅供一次性制作留档，运行时不引用；日常直接编辑保存的 tscn。不要重新运行原 `village/tools/build_village.gd`。`tools/integrate_west.py` 是本次局部接入的记录，已接入后拒绝再次执行。
