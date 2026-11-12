# AdvancedMotionBlur 实机对照

## 直接载入验收副本

`H:\Coding\MotionBlurReview\Scenes` 的 PMM／EMM 对照副本使用 `80f166d`。打开相应 PMM 即可测试带场景、切镜、两种抖动和预编译。对应工程名和帧位见 `H:\Coding\MotionBlurReview\READ-ME.md`。这些副本使用本机原工程的绝对资产路径，画面对照使用原控制器。新版控制器表情须在另一个副本中载入后核对。

## 手动切换配置

`dist/review-5763069-combined` 的 `Source` 和 `PrecompiledScene` 都来自 `5763069`。两边初始使用相同的 Scene 配置。`Profiles` 下的文件供源码版切换使用。

用 PMM 副本载入 `Source/AdvancedMotionBlur.x`。在 MME 的 `GeometryData` 页确认分配的效果都来自这一套目录。角色用 `MotionGeometry.fx`，按原工程保留舞台映射和白底的 `DepthVelocity.fx`。需要附件自身拖影时给移动的 `.x` 分配 `RigidMotion.fx`。保持原来的附件绘制顺序。

将 `Profiles/Settings.<配置>.fxh` 复制为 `Source/Settings.fxh` 后重载同一个附件。需要对照历史速度时，从同一起点连续导出。`测试基线.pmm` 用 500–900 帧，500–504 帧用于预卷。

| 配置对照 | 工程与观察点 |
| --- | --- |
| Default／Layered | `测试基线_带场景.pmm`。保持原导出起点，检查 10.167–10.233 秒的右手、栅栏和黄带，重点看 10.200 秒附近的清晰方块 |
| Default／CutProbes | `测试基线.pmm`。检查 531、751、831 切入首帧和 505–520、650–750、800–830 的连续运镜 |
| CutProbes／CutProbesWorld | 同一工程，比较 751、831 的角色自身拖影。可另用 `MB_DEBUG=5` 检查模型坐标，随后恢复 `MB_DEBUG=0` 再看成片。另用一次角色瞬移检查是否出现满长拖尾 |
| Scene／SceneJitter | 同一段快速挥手或高反差细线，按 100% 比例比较规则残影和细颗粒 |
| Scene／SceneDither | 同一段淡拖影或渐变，按 100% 比例检查色带及 4×4 图案的可见度 |
| Scene／RGBA | 隐藏不透明背景，以保留 Alpha 的格式导出，按预乘方式分别叠到黑底与白底，检查轮廓外拖尾 |
| Default／P0 | 1080p 和 3840×1728，以相同预览限帧和工程比较无附件、P0、Default。用 Default 连续导出 30／60 fps 对照同一镜头的拖影长度，也可用 `MB_DEBUG=4` 复查不限帧和约 15 fps 预览 |

用 `AdvancedMotionBlurController.pmx` 在 MMD 里核对实时表情，尤其是其他栏的 `Force Cut` 和 `Keep Camera`。在 Scene 配置下另用固定镜头检查两个移动附件、发梢、睫毛和加法材质。出现局部异常时记录配置、帧和材质。

测预编译加载时，将源码版恢复到 `Settings.Scene.fxh`。用两个 PMM 副本分别载入 `Source/AdvancedMotionBlur.x` 和 `PrecompiledScene/AdvancedMotionBlur.x`，对齐各自的 `GeometryData` 路径后，比较相同场景的载入时间和同一段导出。要改预编译配置时，先在源码目录设置，再重新生成预编译目录。控制器表情仍可在载入后调整。

记录工程、配置、分辨率、帧率、帧或时间，以及所见现象。优先记录带场景、切镜和抖动对照的结果，作为决定默认开关的依据。
