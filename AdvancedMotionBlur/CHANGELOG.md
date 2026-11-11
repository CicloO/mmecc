# 更新日志

标签格式为 `AdvancedMotionBlur/v<版本>`。

## 0.2.0 · P1 控制器版

- 快速前景的拖尾可延伸到轮廓外（TileMax／NeighborMax），覆盖空白底色和较远的场景；`MB_EXTEND_FOREGROUND=0` 可回到 P0 的轮廓内模糊。
- 描边修正：MMD 原生描边和单像素后处理暗线从相邻表面借用速度，`MB_OUTLINE_MOTION` 控制。
- PMX／PMD 默认记录顶点历史，固定镜头下也有角色动作模糊（`MB_AUTO_MODEL_MOTION`）。
- 新增 PMX 实时控制器 `AdvancedMotionBlurController.pmx`：眉 `Strength ±`、眼 `Shutter ±`、口 `Streak ±`，可注册表情关键帧。
- 快门角固定按 30 fps 的一帧计算，30 和 60 fps 导出的拖影长度相同；删除 `MB_OUTPUT_FPS`。
- 修正载入后画面偏移（全屏四边形局部 UV 与半像素补偿）。
- 目录改为 `src/`、`docs/`、`fixtures/`、`tools/`；新增参数手册 `docs/PARAMETERS.md`。
- 尚未在 MMD 实机验收控制器，见 `docs/VALIDATION.md`。

## 0.1.0 · P0

- 首个原型：深度重建相机运动的动态模糊，可为指定模型开启顶点历史。
