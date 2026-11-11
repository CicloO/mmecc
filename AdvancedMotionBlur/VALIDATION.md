# P0 验证与后续计划

## 技术依据

| 项目 | 实现 |
|---|---|
| MME 捕获场景 | 使用 `ScriptExternal=Color` 捕获场景，`OFFSCREENRENDERTARGET` 单独为对象分配辅助效果 |
| 深度 | D24S8 用于辅助几何遮挡测试。着色器将 `log2(viewZ)` 写入 RGBA16F 的 B 通道，供后处理采样 |
| 运动矢量 | 从深度与上一帧相机矩阵重投影。实验性模型路径按顶点索引记录变形后齐次投影坐标 |
| 跨帧状态 | 使用相机历史和顶点图集，校验时间、输出尺寸和顶点时间戳 |
| 透明材质 | 用材质 Alpha 与贴图 Alpha 估计覆盖，半透明和加法材质使用原色保护 |
| D3D9 / SM3 | 使用 `vs_3_0`、`ps_3_0`、浮点颜色 RT 与点采样。模型路径额外需要顶点纹理读取和 MME 的 `_INDEX` |

参考 [MME 0.37 参数](https://kamedesuyo.github.io/MME_REFERENCE/sections/section2.html)、[MME Script](https://kamedesuyo.github.io/MME_REFERENCE/sections/section3.html)、[Microsoft ps_3_0](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx9-graphics-reference-asm-ps-3-0)。

## Soboro 基线

Soboro 的发行说明记载 2.2 侧重修正与视频用途，3.0 增加静画质量与开销。原版包的下载链接跳转到登录，社区记录保留两版默认 512×512 顶点图集的片段。已实际下载并检查 ikeno 的 3L v003 源码，文件 MD5 与发布页相符。该版本继承 Soboro 的索引点写与顶点历史复制，同时输出深度。3L 使用 1024×512 图集，并改变了切镜时的相机运动处理。 [Soboro 发行说明](https://web.archive.org/web/20180525074555/https://ch.nicovideo.jp/sovoro_mmd/blomaga/ar214316) · [512×512 记录](https://pip-mmd.hatenablog.com/entry/2022/12/04/183344) · [3L v003 源码包](https://ux.getuploader.com/ikeno/download/250)

## 当前结果

- 原版 MMD 9.32 x64 与 MME 0.37 已在隔离 Wine 环境启动。原版 MMD 可执行文件的 SHA-256 为 `07516fd3bf1e6b1339836b6773a156f61bdd6f848eeb621fdda012375df313a1`。
- 本版的主效果、深度效果、三个质量档与四个调试视图均通过 Microsoft D3DX9 编译。顶点路径以 `TEXCOORD7` 代入 MME 专用的 `_INDEX` 后通过独立编译，顶点索引实际绑定由 MME 宿主负责。
- 在 Wine 10 + llvmpipe 中，MMD 加载了启用 `MB_DEBUG=2` 的附件，原生 `D3DCompiler_43.dll` 编译后，预览大部分像素输出 RGB `(128, 128, 0)`，与静止时的 `(0.5, 0.5, 0)` 一致。[实测截图](validation/MME-static-motion.png)
- 默认附件 `AdvancedMotionBlur.x` 也通过原版附件载入对话框，出现在 MMD 的附件面板。[载入截图](validation/MME-default-load.png)
- 早期合成 PMX 在未载入任何动态模糊附件的复测中，同样触发 MMD 访问异常，因此从交付包移除。正式测试使用普通 .x 场景和 MMD 自带模型。Windows 驱动、动态像素与 AVI 帧序需单独验收。
- Microsoft D3DX9 成功解析发布用载入附件和替换后的场景附件。场景包含 20 个顶点、10 个三角形和 5 个材质。相机和右臂 VMD 通过了文件结构检查。
- 数学参考测试覆盖静止相机、平移、旋转与垂直方向符号，验证了 30/60 fps 快门缩放、速度上限、重复帧和倒放的历史条件、跨层深度拒绝及 512² 图集索引边界。

## 可重复场景

相机、深度与透明测试使用附件 `fixtures/BlurP0_Stage.x`，再在镜头模式载入 `BlurP0_Camera.vmd`。场景包含前景红黄条、后方蓝色平面和半透明绿片。固定相机的骨骼测试使用 MMD 自带的 `UserFile/Model/Miku_Hatsune.pmd`，在模型模式加载 `BlurP0_Arm.vmd`，观察右臂和静止区域。

| 场景 | 比较内容 |
|---|---|
| 固定模型与相机平移／旋转 | 速度方向、同层模糊、边缘深度对齐 |
| 固定相机与骨骼快速摆动 | 关节至末端的速度变化、静止背景、停止帧 |
| 红色前景与蓝色背景 | 逐像素串色与薄边缘保留 |
| 相机 30→31 帧硬切、跳帧、后退和暂停 | 速度归零与首帧表现 |
| 半透明材质与透明背景 | 覆盖图、输出 Alpha、黑白底合成 |
| 高顶点 PMX、1080p／4K、Ray-MMD／sdPBR | 顶点上限、帧时和其他 MME 的绘制顺序 |

对照时分别加载 Soboro MotionBlur2.2／3.0、本原型与 Eevee 参考，按相同时间线、分辨率和快门对齐。先用相机匀速平移匹配拖影长度，再看骨骼、轮廓和切镜。每次只保留一个动态模糊效果。

## 下一阶段

1. 在 Windows + NVIDIA 完成 1080p、30/60 fps 的实际导出验收，再覆盖 4K、PMX 骨骼、Morph、IK、Bullet 和设备重置。
2. 在实测对齐的运动与深度上加入 TileMax／NeighborMax 和前景覆盖扩张，专项检查高速薄边缘。 [Guertin 等人的特征感知重建](https://research.nvidia.com/publication/2013-11_fast-and-stable-feature-aware-motion-blur-filter)
3. 评估预乘色与透明覆盖，验证 Ray-MMD／sdPBR，再独立验证子帧求值和 MMDEncoder 快门累积。 [Blender Eevee 运动模糊](https://docs.blender.org/manual/en/4.5/render/eevee/render_settings/motion_blur.html)
