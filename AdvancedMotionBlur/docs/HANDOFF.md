# 交接：Claude → Codex（2026-11-12）

用户确认当前版本的观感就是想要的，接下来让 Codex 一次把剩余的缺陷修完。本文是交接单。背景细节以 `docs/ROADMAP.md`（问题 A–P、阶段方案）和 `docs/VALIDATION.md`（证据）为准。

## 0. 先保护现在的版本

用户在 MMD 里直接载入 `H:\Coding\mmecc\AdvancedMotionBlur\src\`，这个目录必须保持现在的版本。

- 基准提交：`AdvancedMotionBlur` 分支上标题为“AdvancedMotionBlur: tuned defaults, edge and outline fixes, faster load, Codex handoff”的提交（下文称“基准”）。本地另有 `git archive` 打的快照 `AdvancedMotionBlur/dist/MMD-AdvancedMotionBlur-baseline-2026-11-12.zip`，不入库。
- **不要在 `H:\Coding\mmecc` 这个检出里切分支、改 `src/` 或提交。** 在单独的工作树里开新分支：

```bash
git -C H:/Coding/mmecc worktree add -b AdvancedMotionBlur-codex H:/Coding/mmecc-codex AdvancedMotionBlur
```

- 之后所有改动只提交到 `AdvancedMotionBlur-codex`。不动 `AdvancedMotionBlur` 和 `main`，不推送，不打标签。用户实测后决定是否合并。
- 用户测试时从 `H:\Coding\mmecc-codex\AdvancedMotionBlur\src\` 载入，与基准并排对比。

## 1. 硬性原则

1. 普通帧继续和基准做像素与观感对照。会改变画面的候选功能用 `Settings.fxh` 开关提供对照，验收通过后在开发分支默认打开。涉及原生 MME 绑定或用户场景的改动，在对应实机验证前保持候选状态。
2. 每项一个提交，提交前跑第 4 节的两项检查。
3. 文档全部中文，按现有风格更新：`CHANGELOG.md`“未发布”一节、`docs/VALIDATION.md`（区分已运行与“未运行”，不把编译通过写成画面验收）、新增开关写进 `README.md` 参数表和 `docs/PARAMETERS.md`。
4. 提交署名只用 CicloO，不加 `Co-Authored-By` 或任何 AI 署名。
5. `test/` 下的视频、根目录 `.pmm` 只在本地，不入库，也不上传任何远端。3L（`F:\MMD\Effect\MotionBlur3L_v005`）只读参考，不复制进仓库，F 盘原件不能改。

## 2. 当前状态（基准）

- 默认值：快门 180°（按 30 fps 的一帧计算）、`MB_MOTION_SCALE 1.3`、`MB_MAX_STREAK 64`、`MB_SPEED_THRESHOLD 3`、`MB_QUALITY 1`（用户定，按长度分配、间隔 2 px）、`MB_EDGE_BACKGROUND 1`、`MB_TRAIL_SPREAD 0.35`、`MB_LINEAR_COLOR 1`、`MB_OUTLINE_SEARCH 3`、`MB_OUTLINE_FRINGE 1`。
- 控制器 PMX 7 个表情：Strength±、Shutter±、Streak±、Threshold。表情名必须与 `src/Controller.fxh` 一致，PMX 用 `tools/build_controller.py` 重新生成。
- 描边虚点：原因是 MMD 主画面开抗锯齿而辅助缓冲 `GeometryData` 不开，轮廓上的柔边像素被记成背景或半透明。`MB_OUTLINE_FRINGE` 已处理两种情况；`测试1.1-8.avi` 里大部分消失，右腿右缘上段还剩几个很淡的点，待基线复查。
- 载入：MME 用 `d3dx9_43` 编译，`AdvancedMotionBlur.fx` 已从约 20 s 降到约 2 s（见 VALIDATION“载入速度”）。
- 实机验收：控制器表情、新默认值、1.1、描边修正都只有用户导出的视频作证据，没有逐项验收记录。

## 3. 任务（按顺序）

| # | ROADMAP | 内容 | 验收（基线帧见第 5 节） |
|---|---|---|---|
| 1 | 1A.1 | 预览帧率（问题 P）：`MB_MAX_FRAME_GAP` 提到约 0.1 s；`dt` 下限放宽（约 500 fps 时帧间隔 2 ms）；顶点历史去掉 `abs(dt - ELAPSEDTIME) <= 0.002` 的比较 | 帧率限制 30／60／无限制／约 15 fps 时 `MB_DEBUG 4` 角色稳定为绿色；导出与基准一致 |
| 2 | 1A.2 | 切镜判定（问题 O）：按 ROADMAP“对 K–P 的审阅”里的屏幕位移判据重写 `CameraInterval()`（取几点深度，用上一帧矩阵重投影，位移中位数超过画面高度的一定比例，且比上一帧位移大数倍才判切镜；上一帧位移存进 CameraState 空闲的 slot 7），保留朝向和投影类型的旧判据兜底。顺带把 `CameraInterval()`、`ExposureScale()` 挪到全屏四边形的顶点着色器 | 531、751、831 帧显示原色；505–520 环绕、650–750 慢环绕、800–830 快摇不丢模糊；其余帧与基准一致 |
| 3 | 1A.3 | 手动覆盖（问题 L）：控制器加“强制切镜”“强制不切”两个表情，压过自动判定 | 两个表情可注册关键帧并生效；PMX 用脚本重建，`Controller.fxh` 同步 |
| 4 | 3.0＋3.1 | 切镜帧保留角色动作模糊（问题 K）：顶点图集改存投影前位置，上一帧镜头矩阵单独保存；切镜帧用当前矩阵重投影上一帧位置 | 不切镜时 `MB_DEBUG 2` 与基准逐像素一致；切入帧角色有动作模糊、背景为原色。先实测 MME 下 PMX 的 `POSITION` 是不是世界空间 |
| 5 | 3.4 | 瞬移保护（问题 I）：世界空间位移超过阈值时该顶点历史判无效，回到镜头速度 | 构造一次瞬移，该帧角色不被拉满 |
| 6 | 性能 | 先测再改：1080p 与 3840×1728 下读 MMD 帧率，对比无效果、`MB_EXTEND_FOREGROUND 0`、默认。候选：NeighborMax 为零的分块整块跳过 `ExtendForeground`；顶点少的模型 `MB_HISTORY_SIZE 256` | 记录数据；输出与基准一致 |
| 7 | 可选 | 1.4 拖影上限按画面高度（D）已通过离屏对照并默认打开。2.3 拖尾写 Alpha（F）、3.2 附件自身运动（G）按各项验收结果启用 | 1.4 在 1080p 与原路径一致，其他尺寸可关闭开关对照固定像素 |

**不要做：** 1.2 采样抖动（用户偏好残影状拖影）；任何改变默认观感的“画质提升”，包括 1.3、2.1、2.2、3.3，除非做成默认关闭的开关。

## 4. 每次提交前的检查

```bash
pwsh tools/fxc_matrix.ps1
```

脚本列出的配置与效果必须 0 失败。新开关要加进脚本的 `$cases`。

```bash
python -I tools/d3dx_compile_time.py <临时目录>/amb-fxc-matrix/default/AdvancedMotionBlur.fx
```

这一步用 MME 实际使用的编译器计时，基准约 2 s，明显变慢要查原因。

## 5. 实机对照（由用户在 MMD 里跑，Codex 记“未运行”）

- 工程：`H:\Coding\mmecc\AdvancedMotionBlur\测试基线.pmm`（本地）。导出范围 500–900，从 500 起连续导出，500–504 是预卷。分段见 VALIDATION“阶段 0 基线工程”。
- 对照帧：515、525、531、536、539、590、645、700、751、815、831、860。
- 3L 对照：`测试基线_3L.pmm`，附件 Si 为 5（用户设定，不是默认）。
- 要逐像素看的调试视图用无压缩导出。utvideo 的 yuv420p 会把 1 px 的覆盖色抹成假颜色。

## 6. 已知的坑

- **编译器**：MME 用 `d3dx9_43`。它会逐次模拟部分循环，单个很小的 pass 也可能编译约 10 s。参考 `Foreground.fxh` 的常量上限与 `[fastopt]` 分段循环。改完用旧编译器重新计时。
- **寄存器余量**：`BuildMotionField` 单独按 ps_3_0 编译会报 X4505，放在效果里能过。改描边代码后要确认整个效果仍能编译。
- **`_INDEX`**：`Geometry.fxh` 用 MME 的顶点序号语义，FXC 和 `d3dx9_43` 都不认识。检查脚本在临时副本里换成 `TEXCOORD7`；源码里不能这么换，MME 不会往 TEXCOORD7 填序号。
- **覆盖码**（`GeometryData.a`）：0 空，1 相机路径，2 已在几何阶段校验过的历史或旧版顶点路径，3 半透明，4 原生描边。默认裁剪坐标顶点历史用 0 到 0.5 之间的正值携带间隔，合成阶段与相机间隔核对。场景里的 `白背景.x` 会写成 1。
- **抗锯齿**：主画面开抗锯齿、离屏缓冲 `AntiAlias = false`，边缘像素两边分类对不上，这是描边虚点的根源。改描边或边缘逻辑时，开抗锯齿和关抗锯齿两种都要看。
- **用户本地设置**：用户会为了导出临时改 `Settings.fxh`（如 `MB_DEBUG 4`）。不要把这类临时改动当默认值提交；`tools/fxc_matrix.ps1` 会强制 `MB_DEBUG 0`。
- **3L 的 Si**：3L 的速度是每帧位移，60 fps 下 Si 约 2 才等于 30 fps 的长度；死区在乘 Si 之前减。对比时先用 505–520 对齐拖影长度。

## 7. 交回时请写

按 `CLAUDE.md`：每项的改动摘要、检查命令与结果、未完成项、需要用户在 MMD 里看的帧，写进本文末尾或 VALIDATION。
