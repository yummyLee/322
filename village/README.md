# 窑村：参考图 3D 像素场景

## 地面、旧屋与北侧调整（2026-09-17）

- `Terrain/BlendedVillageGround`：已保存的地表分块，草地、黄土、暗土与腐叶土连续混合，加入深浅斑驳；保留原平地高度与通行关系。复用乱葬岭四类地表材质，西侧接口色彩一致。
- `LivedInGroundDetails`：墙脚草、林缘草簇、零散砾石与陶土碎屑。
- `Buildings/<房屋>/AgeAndRepairs`：13 座原房屋的灰泥脱落、露砖、细裂缝、窗户补木、旧木料、陶罐与墙脚苔色；`weathered_plaster.gdshader` 补充受潮和雨痕，旧瓦与茅草束做了局部错位和色差。原有门口与通路保持清晰。
- 北院两座房屋、院墙和菜地向北移动 5 单位；北侧 32 棵边界树随碰撞向北退让，移除 7 棵树，留出院落与林缘之间的空间。
- 编辑入口仍是 `yao_village.tscn`，运行入口仍是 `main.tscn`，无需运行制作脚本。

`tools/validate_lived_in.gd` 验证移动后的树与房屋碰撞、北院通行，以及乱葬岭两座新建筑门洞的往返行走。`tools/verify_lived_in_gpu.gd` 验证原菜单、像素设置和新材质开关，并输出实际截图。均已通过 `failures=0`。

本轮截图位于 `burial_ridge/preview_village_weathered_overview.png`、`preview_village_weathered_house.png`、`preview_village_north.png`。`tools/refine_lived_in_environment.gd` 及对应 `finish_*`、`fit_entry_floors.gd` 为已应用的离线制作记录，日常编辑不要重复执行。

## 西侧乱葬岭扩展

`yao_village.tscn` 已接入 `WesternBurialRidge`，向左连接乱葬岭墓地、枯树林、芦草坡和两座林间茅屋。新区可直接展开子节点编辑，也可打开 `burial_ridge/world.tscn` 单独调整。运行入口、出生点、原菜单与默认镜头沿用现有设置；沿西侧菜地外围道路向左走即可进入。详细节点分组和截图见 `burial_ridge/README.md`。

## 接入新版人物

F5 仍使用原有 `main.tscn`，菜单、村庄布局、原相机角度、默认视野与环境采样设置保持原样。只在 `WorldViewport/YaoVillage/Hero` 下加入新版 `hero_v2/traveler.tscn`，出生位置为 (-4, 0.15, 5)，可在主场景中直接编辑。

方向键行走，Shift 跑步；沿用村庄原来的跟随、滚轮缩放、空格自动旋转、R 重置、Esc 设置。菜单打开时暂停移动；关闭后 C 换装、H 显隐头发。人物保留独立照明、真实环境投影和深度遮挡，并与村庄像素网格 1:1 对齐，配备风格统一的边缘与法线描边后处理（PixelOutline）。设置面板中的“轮廓描边”与“边缘提亮”会同步控制环境和人物。

`character_rendering.gd` 只负责人物显示同步、描边同步和深度合成，人物、独立视口、描边节点与相机均是保存的实际节点。碰撞沿用村庄已有的地面、房屋、树干、墙体和边界；部分小装饰没有碰撞。

## 运行与编辑

- F5：运行窑村像素场景，入口 main.tscn。
- 编辑模型：打开 yao_village.tscn，切换 3D。选中节点后按 F 聚焦。
- Buildings 下按房屋分组；屋顶在 Roof 下，每片瓦均可编辑。
- VillageLife：牌坊、村口大树、水井、磨盘、布架、陶罐和其他道具。
- ForestBoundary、NortheastCliffs、VegetableGardens：树林、山石、菜地。
- RenderRig：相机、方向光、环境和后处理；这些设置同样保存在场景中。
- 编辑后 Ctrl+S，再 F5。无需运行任何生成脚本。
- 公用 Mesh / Material 若仅改单个物体，先在检查器中将资源“唯一化”。
- 后处理 PixelOutline 在编辑器里默认隐藏；运行时自动开启，避免遮挡 3D 编辑视图。

## 控制

方向键行走、Shift 跑步，滚轮缩放，空格旋转，R 复位镜头。
右上角齿轮打开设置面板，可调整采样、描边、分阶光照、边缘提亮、相机吸附和自动旋转。
镜头滑块调整可视范围（30%–150%）；“重置镜头”恢复初始位置、缩放和角度。
Esc、关闭按钮或点击面板外关闭；菜单打开时暂停键盘平移和自动旋转。
渲染分辨率始终为 1920×1080，窗口默认 1920×1080；缩放窗口只改变显示尺寸，保持 16:9。
像素化效果开关启用/禁用像素分块；像素大小滑块范围 1–12，默认 3（3×3 输出像素组成一格）。
1 为原始清晰度，数值越大颗粒越粗。颜色、深度描边与法线提亮使用同一采样网格，
相机吸附同步匹配像素大小。1920×1080 渲染和界面分辨率保持不变，菜单文字不会像素化。
1–5 和空格快捷键仍可在关闭菜单时使用。设置面板的控件保存在 main.tscn 中，可直接编辑。

## 范围

按用户提供的“窑村v1.png”重建位置关系和主要地标，所有可见物体为真实 3D 网格。
当前为可编辑的风格化初版：保留祠堂、北院、西院、作坊、菜地、山林与村口布局；
建筑比例、屋顶形状、岩壁、树叶仍是几何化近似，未逐像素复刻原图手绘细节。
主场景已接入新版人物及保存的行走碰撞；未加入导航、烟雾或剧情逻辑。相机旋转仍会发生像素变化。

## 文件与复用

- yao_village.tscn：独立静态场景，运行时不会重建。
- main.tscn / viewer.gd：低分辨率视口及交互。
- style.gdshader：分阶光照、轻微世界坐标颗粒。
- 复用 pixel_lab/outline.gdshader；旧测试场景保留在 pixel_lab。
- tools/build_village.gd：可选的制作源代码，不是运行依赖。
- tools/bake_helpers.gd：通用几何与 tscn 烘焙助手。
- 个人 skill：C:/Users/Administrator/.codex/skills/godot-reference-to-pixel3d/SKILL.md（使用本对话的建模构件、渲染资产和独立项目验证流程）。

仅在明确需要重新制作时运行生成器。它要求 -- --bake，已有输出还要求 --overwrite；
重建会覆盖 yao_village.tscn 的手动修改。日常直接编辑 tscn。

## 验证

Godot 4.7.2 / D3D12 Forward+ / RTX 5080，实际 GPU 验证像素和普通 3D 两种模式。
validate_scene.gd 检查节点归属、关键地标、编辑器后处理隐藏和编辑变换的持久化。
preview.png、preview_plain.png 为两种模式实际运行截图；render.png 为低分辨率原始画面。
截图命令附加 -- --capture；普通模式再附加 --plain；局部放大可附加 --detail。
