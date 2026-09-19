# 乱葬岭左山洞

这是独立的 Godot 4.x 3D 场景，用于窑村同款 3 渲 2 预览。分区父节点按建模指导保留了 `J0`～`J13` 的空间身份；洞壁、地面、桥、浅水、车、骨堆、门、支撑木和灯光都是写入 `world.tscn` 的可编辑节点。

- 编辑入口：[world.tscn](world.tscn)
- 运行入口：[main.tscn](main.tscn)
- 生成辅助脚本：`tools/build_scene.gd`（仅用于本轮烘焙，不在运行时生成或覆盖场景）
- GPU 预览：`preview.png`、`preview_plain.png`

场景保持现有项目启动入口不变；后续若要接入地图、角色碰撞或 J12→J8 的交互开关，再以这些语义节点为连接点添加。
