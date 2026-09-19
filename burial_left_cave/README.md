# 乱葬岭左山洞

这是独立的 Godot 4.x 3D 可编辑场景。J0～J13 的原有区域位置、多个墙体围合关系和连接账本均保留；本轮只把各区域地面和道路改为连续表面，并保留洞壁、洞口、台阶和区域间高差。

- 编辑入口：[world.tscn](world.tscn)
- 运行入口：[main.tscn](main.tscn)
- 生成辅助脚本：`tools/build_scene.gd`（仅用于显式 `--overwrite` 的一次性烘焙）
- 静态规范验证：`tools/validate_scene_spec.gd`
- 玩家路径验证：`tools/validate_walk.gd`

`CaveTerrain/J0_...J13_...` 是独立区域节点；`CaveRockShell` 保存围合墙体和石缘；`SavedWallCollisions` 保存洞壁、区域边界、连续区域地面和道路碰撞；`RegionEntrances` 保存入口连接标记。查看器支持方向键平移、滚轮缩放，以及鼠标右键选中并拖动镜头。

本场景不替换 `village/main.tscn`，也不依赖运行时脚本生成或覆盖模型。
