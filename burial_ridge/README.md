# 窑村西侧：乱葬岭

按 `乱葬岭左1完全.png` 在原村庄西侧扩展，运行入口仍是 `res://village/main.tscn`。

## 编辑

- 整体编辑：`village/yao_village.tscn` → `WesternBurialRidge`（已启用可编辑子节点）。
- 新区单独编辑：`burial_ridge/world.tscn`。选择任意地标后按 F 聚焦；所有模型和碰撞均为已保存的真实节点。
- `TerrainAndPaths`：冷灰墓地地表；`HandWorkedRoads` 下是细化的村间土路、墓地小径、入户踏石与路肩过渡。
- `Graveyard`：22 处普通墓碑、一座高碑、石龛、残墓、废弃推车和木标。
- `BareRidgeTrees`：10 棵可单独调整的枯树；`LivingForest`：林缘树群。
- `ForestHomesteads`：两座茅屋、晾架、陶罐、柴堆及院落道具。
- `BrokenRockTerraces` / `MeadowAndGroundDetails`：断石坡、芦草与地面细节。
- `SavedWalkCollisions`：地面、房屋、树干、墓碑及外围边界碰撞。
- `AncientRoadsideDetails`：矮路碑、粗石供台、陶制香盏、小供碟、柴束、破陶罐和落枝。

## 人物比例与道路细化

以当前玩家 1.86 单位的碰撞身高校准，玩家本身不变。普通墓碑整体缩至初版的 66%，高碑约高 1.65，石龛约高 1.60，推车约长 2.54、宽 1.62、高 0.75。岩块缩至约六成，芦草缩至约六成，树木适当收小；碰撞跟随主要物件调整。两座茅屋收窄平面占地，屋顶与墙顶降低，门框保留 2.08 单位高度。

村间土路常规宽约 2.7，墓地小径约 1.35，入户路约 1.45–1.55。路径使用细分曲线和不规则宽度，分为踩薄草层、碎土路肩、压实泥土，并加入断续车辙、浅色磨损、潮土斑、半埋碎石与路缘杂草。旧铺石集中在岔路口，门前有散铺踏石，守墓人茅屋旁有干排水沟。墓地十字木标改为竖式旧木牌。

新区沿 X 负方向展开，主路从原村西边约 `(-23, 0, 7)` 向左接入。沿村西菜地外围土路穿过林间缺口即可进入。保留原出生点、原村建筑和默认镜头。只移动了挡住接口的六棵旧树，并同步移动树干碰撞；原 X=-40 的边界碰撞已禁用，新西边界为 X=-87。

共享材质直接使用 `village/style.gdshader`，沿用当前窑村的分阶光照和独立人物像素合成。没有另建运行时渲染系统。单独调整共享网格/材质时，先将相应资源唯一化。

## 验证与截图

本次验证：Godot 4.7.2 / D3D12 Forward+ / RTX 5080。静态场景与通行检查 `failures=0`；人物比例检查 `failures=0`；GPU 和原菜单检查 `failures=0`。细化后新区共 10,385 个保存节点，其中 9,112 个为真实 MeshInstance3D。通行验证覆盖村西接口到墓地的九段连续主路，不代表所有装饰区域均可通行。

- `tools/validate.gd`：保存节点/归属、地标、磁盘编辑重载、原入口集成、旧树碰撞同步，以及使用真实角色碰撞体从村西通路连续走到墓地。
- `tools/verify_gpu.gd`：加载原 `village/main.tscn`，检查原出生点、设置开关、像素网格同步，并输出实际 D3D12 Forward+ 截图。
- `tools/check_human_scale.gd`：读取保存模型的实际几何包围盒，对照玩家身高和保留的门框高度。
- `preview_human_scale.png`：玩家与墓碑、石龛同框；`preview_road_detail.png`：车辙土路与入户踏石近景。
- `preview_overview.png`：新区全景；`preview_joined.png`：新区与原窑村同框；`preview_detail.png`：墓地区域；`preview_seam.png`：连接处；`preview_plain.png`：非像素对照；`preview_settings.png`：原设置菜单。
- 截图工具只临时调整查看位置，不修改保存的相机或出生点。

地形按参考图的分区、道路与地标关系做了几何化近似；不是逐像素复刻。墓碑字痕为抽象磨蚀刻痕，图中的手绘裂纹、草叶和土坡高差进行了简化。主路和主要障碍有碰撞，小碎石、草丛及部分装饰石坡没有精细碰撞。

`tools/build_scene.gd` 是初版制作留档，重跑会丢失后续细化；日常直接编辑保存的 tscn。`tools/refine_saved_scene.gd` 是本次对已保存节点的局部修改记录，带版本标记防止重复缩放，运行时不引用。不要重新运行原 `village/tools/build_village.gd`。`tools/integrate_west.py` 是初次接入记录，已接入后拒绝再次执行。
