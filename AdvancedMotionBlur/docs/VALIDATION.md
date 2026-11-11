# P0 基线、P1 验证与后续计划

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

## Windows 反馈与本次修订

- Windows MMD 实测反馈：载入 P0 后画面偏移，固定镜头下默认看不到角色拖影。用户手动给模型分配 `MotionGeometry.fx` 后，观察到角色动作模糊。复现工程保存的 `测试.emm` 将角色在 `GeometryData` 页显式映射到 `DepthVelocity.fx`。
- 主合成改用 MME 全屏四边形的局部 UV，并在采样时补偿 D3D9 半像素。相机状态写入及顶点图集复制也改用目标局部 UV。PMX／PMD 默认在 `GeometryData` 启用 `MotionGeometry.fx`，附件 Si 通过 MME 的自身缩放绑定读取。
- Windows SDK 10.0.26100 FXC（`/T fx_2_0`）通过主效果、深度效果、三个质量档、四个调试视图及禁用自动角色映射的编译。顶点效果用临时副本将 MME 专用 `_INDEX` 替换为 `TEXCOORD7` 后通过同一编译，原文件保留 `_INDEX`，仍需在 MME 中确认绑定。
- 本次会话中 MMD 出现空指针错误。Windows 错误窗口和日志未能定位故障模块。独立 MMD 副本已打开，用于人工复测。
- 待实机核验：空工程载入前后静止画面对齐，Si=1 时固定镜头的角色拖影、只有镜头运动时的拖影、Si=0 对照。描边与深度边缘、透明输出和 30／60 fps 导出也待实机验收。

## P0 实机视频基线

用户确认修订版在 MMD 中正常作用。进入 P1 前在 `test/` 中留下四段实机视频。用 FFprobe 检查视频流并用 FFmpeg 抽帧查看角色运动和场景构图。

| 文件 | 实际分辨率 | 帧率 | 视频帧数 |
|---|---:|---:|---:|
| `01 30fps_0000-1000f.mp4` | 1920×1080 | 30 | 1001 |
| `01 60fps_0000-1000f.mp4` | 1920×1080 | 60 | 2002 |
| `1080p_0001-0201f.mp4` | 1920×964 | 30 | 201 |
| `4k 30_0000-0200f.mp4` | 3840×1728 | 30 | 201 |

视频记录了 P0 的渲染输出。快门配置、导出耗时和透明通道需要另外测量。

## P1 前景拖尾

- `Foreground.fxh` 把像素速度、对数深度和几何覆盖写入全分辨率 RGBA16F。TileMax 按约 32 像素宽的分块找主速度，NeighborMax 把搜索方向传播到可能被拖尾覆盖的邻近分块。重建时按源像素自身的速度和深度检查它能否覆盖目标。远处和空白处可接收较近的拖尾，较近的遮挡层和半透明像素保留原色。 [Guertin 等人的特征感知重建](https://research.nvidia.com/publication/2013-11_fast-and-stable-feature-aware-motion-blur-filter)
- `MB_EXTEND_FOREGROUND=0` 可对照 P0。关闭时和调试模式下跳过新渲染目标及三个新 pass。开启时额外的全分辨率速度纹理约占 15.8 MiB（1920×1080）或 50.6 MiB（3840×1728），另有小尺寸分块纹理和深度表面。
- Windows SDK FXC 编译通过三个质量档、四个调试视图和关闭扩张的回退路径。
- RTX 5090 D 上用 D3D9 HAL 离屏执行四个 P1 像素着色器，在 103×69／30、1920×1080／60、3840×1728／30 的合成图上通过像素检查。分别注入固定镜头下的模型速度和纯镜头位移，检查细前景跨分块拖到白底和远层、近层遮挡、半透明保护、最右边缘、输出 Alpha，以及重复帧、跳帧、切镜和 Si=0 时回到原色。 [离屏对照图，左为原色，右为 P1](validation/P1-offscreen-foreground.png)
- 原生 MMD 分别完成 P0 对照和 P1 的 640×362、30 fps、35 帧 AVI 导出。这个环境里的 `BlurP0_Stage.x` 在卸下模糊效果后仍输出白画面，两段 AVI 只证明载入和导出完成，无法判断拖尾。

## P1 描边修订

- 全渲染工程的 EMM 为角色分配了 `MotionGeometry.fx`，同时包含 Croquis 后处理。修订前辅助几何的 `edge` pass 为空，主画面与速度缓冲在外轮廓上会产生覆盖差异。
- MMD 原生描边使用宿主已扩张的顶点写入辅助深度。模糊重建从相邻同深度表面借用速度。已合成进场景颜色的单像素暗线通过两侧颜色和前后景深度约束识别。两条路径共用现有运动缓冲。
- FXC 通过主效果的三个质量档、四个调试视图、关闭描边和 P0 回退的配置。深度及顶点辅助效果通过编译，后者在临时副本中用 `TEXCOORD7` 代替 MME 专用 `_INDEX`。
- RTX 5090 D 的 D3D9 离屏测试通过 103×69／30、1920×1080／60 和 3840×1728／30。检查了原生描边覆盖编码，前景速度与深度继承，空底和远层上的单像素暗线，同层暗纹、半透明保护、静止原色、Alpha 和 Si=0 对照。
- 待用原全渲染工程验收 MME 原生描边顶点绑定和 Croquis 合成顺序。用同一段裙摆或小腿运动对照 `MB_OUTLINE_MOTION=0/1`。后处理描边厚度超过一像素时仍可能出现残余硬线。

## P1 PMX 控制器

- 用户反馈后修订：P1 与描边开关移出控制器，只保留在 `Settings.fxh`；`Streak ±` 从眉栏移到口栏。`MB_OUTPUT_FPS` 及 `FPS 30/60` 表情删除，快门角固定按 30 fps 的一帧计算。屏幕速度按秒计算，帧率参数和快门角、Si、强度在公式里是同一个乘数，可以互相替代；固定 30 后，60 fps 导出也保持 30 fps 时期的拖影长度（此前把帧率设为 60 会让拖影减半）。
- `tools/build_controller.py` 用 Python 3.14 重新生成的 PMX 与 `src/AdvancedMotionBlurController.pmx` 逐字节一致（1007 字节）。按 PMX 2.0 规格逐段解析到文件末尾：UTF-16LE、全部索引 1 字节，一个 Alpha 为 0、无描边无阴影的材质，一根 Root 骨骼，6 个零偏移顶点表情（眉 2、眼 2、口 2），Root 与表情两个特殊显示枠，无刚体和关节。`Controller.fxh` 读取的 6 个 `item` 名与 PMX 表情名一一对应。
- Windows SDK 10.0.26100 FXC（`/T fx_2_0`）编译含控制器绑定的版本：主效果、`DepthVelocity.fx` 与 `MotionGeometry.fx`（临时副本用 `TEXCOORD7` 代替 `_INDEX`），覆盖默认、三个质量档、四个调试视图、`MB_EXTEND_FOREGROUND=0`、`MB_OUTLINE_MOTION=0` 和 `MB_AUTO_MODEL_MOTION=0`，共 30 次编译均通过，仅有 X4717 弃用警告。
- 未运行：在 MMD 中载入控制器 PMX、确认 `GeometryData` 隐藏控制器、各表情的实时绑定与关键帧导出，以及未载入控制器时与 P1 无控制器版本输出一致。

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

1. 用已有 PMX 动作和有可见前后景的工程在 MMD 对照 `MB_EXTEND_FOREGROUND=0/1`，重点看手脚与细饰物轮廓、前后景交叉、切镜及 30／60 fps 导出。测量 1080p 和 3840×1728 的额外开销，覆盖 Morph、IK、Bullet 和设备重置。
2. 评估预乘色与拖尾 Alpha 覆盖，验证 Ray-MMD／sdPBR，再独立验证子帧求值和 MMDEncoder 快门累积。 [Blender Eevee 运动模糊](https://docs.blender.org/manual/en/4.5/render/eevee/render_settings/motion_blur.html)
