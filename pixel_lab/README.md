# 3D 像素渲染实验

F5 运行项目，或 F6 运行 main.tscn。

## 编辑模型与场景

双击 world.tscn，在顶部切换到 3D。所有模型已保存为可编辑节点，按
Terrain（地形）、Bridge（桥）、House（房屋）、Path（路）、Trees（树）、
Rocks（石头）、Grass（草）分组。每棵树都有独立父节点，可整体移动。

选中节点，用移动、旋转、缩放工具调整，或在检查器的 Transform 输入数值。
选中 MeshInstance3D 后展开 Mesh，可修改 BoxMesh 的 Size、圆锥的半径和高度等。
Geometry 下的 Material Override → Shader Parameters → Base Color 可改颜色。
复制后若只想改变其中一个模型的网格或材质，先将对应资源设为“唯一化”。
Ctrl+S 保存，然后 F5 看最终像素效果。运行程序使用这里保存的模型，不会重新生成覆盖。
world.tscn 用于编辑几何；相机、灯光和后处理仍由 main.gd 创建，最终效果以 F5 为准。
顶点、边、面的细致建模适合在 Blender 完成后导入 Godot。

- 1：低分辨率 / 高分辨率对照
- 2：深度描边
- 3：分阶光照
- 4：边缘提亮
- 5：相机像素网格吸附
- 空格：旋转相机；方向键：平移；R：重置视角
- 顶部开关也可鼠标操作。

SubViewport 以 384×216 渲染，再进行最近邻整数倍放大。toon.gdshader
实现三阶漫反射，outline.gdshader 使用深度和法线纹理检测四邻域边缘。
需要 Forward+，不支持 Compatibility。

这是受 t3ssel8r 作品启发的原创实验，不是其完整渲染器的移植。
法线提亮是启发式近似，不保证只检测凸边。未实现体积光、反射和精细植被；
水面为静态色块。相机吸附缓解固定角度平移时的像素爬动，未实现亚像素
屏幕补偿，旋转仍有像素变化。

参考：
- https://www.youtube.com/watch?v=ERA7-I5nPAU
- https://www.davidhol.land/articles/3d-pixel-art-rendering/
- https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html

本机使用 Godot 4.7.2 / D3D12 / Forward+ / RTX 5080 验证导入和实际 GPU
渲染，无脚本及着色器错误。preview.png 是运行截图。
命令行附加 -- --capture 可运行后自动截图并退出。
