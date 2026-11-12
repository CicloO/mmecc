# Advanced Motion Blur for MMD 0.2.0 · P1 控制器版

作者：CicloO · 协作：Codex、Claude

Codex 与 Claude 的协作约定见 [CLAUDE.md](CLAUDE.md)。验证证据与后续计划见 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 目录

| 路径 | 内容 |
|---|---|
| `src/` | `.x` 附件、着色器、头文件和可选的 PMX 控制器 |
| `docs/` | [参数手册](docs/PARAMETERS.md)、验证记录和截图 |
| `fixtures/` | 测试场景与动作 |
| `test/` | 用户从 MMD 导出的 P0 对照视频（本地，不入库） |
| `dist/` | 各版本打包的 zip（本地保存，不入库） |
| `tools/build_controller.py` | 用 Python 重新生成 PMX 控制器 |
| [CHANGELOG.md](CHANGELOG.md) | 各版本的改动 |

各版本对应 git 标签 `AdvancedMotionBlur/v*`，可检出或用 `git archive` 打包。

面向原版 MikuMikuDance 9.32 x64 + MME 0.37 的独立动态模糊原型。默认在辅助渲染目标为 PMX／PMD 记录顶点历史，覆盖角色变形和镜头运动。场景附件和缺少有效顶点历史的像素通过深度重建镜头运动。

P1 会把快速前景的拖尾延伸到轮廓外，可覆盖空白底色或较远的场景。固定镜头下也能看到这个变化。将 `MB_EXTEND_FOREGROUND` 设为 0 并重载后，可用同一段连续播放或导出对照 P0 的轮廓表现。

## 安装

1. 解压整个文件夹，保留 `src/` 内 `.x`、`.fx` 和 `.fxh` 的相对位置。首次验证可放在英文路径。
2. 确认 MMD 有 **MMEffect** 菜单。将 `src/AdvancedMotionBlur.x` 当作附件载入。第一次对照时只加载一个动态模糊，在附件绘制顺序中把本效果放在场景附件之后。
3. 连续播放或导出一段角色或镜头有明显运动的片段。附件 **Si** 为强度，1 为默认，0 停用模糊。卸载时从附件面板删除该 `.x`。
4. 首次验证建议用空工程。旧工程的 `.emm` 可能为角色保留 `DepthVelocity.fx` 映射。可在 **MMEffect → Effect Mapping → GeometryData** 选中整个角色的行，改为 `MotionGeometry.fx`。角色在 Main 页保留原有材质。若只需要镜头运动，可在 `GeometryData` 为该角色使用 `DepthVelocity.fx`。

## PMX 实时控制器

将 [AdvancedMotionBlurController.pmx](src/AdvancedMotionBlurController.pmx) 作为模型载入，保持原文件名。在模型面板选中 **AMB Controller** 后调表情。导出前在所需帧注册相应表情。旧工程首次切到控制器版时，重新载入一次 `AdvancedMotionBlur.x` 即可使用新绑定。

| MMD 表情栏 | 控制项 |
|---|---|
| 眉 | `Strength +/−` 调强度 |
| 眼 | `Shutter +/−` 调快门角 |
| 口 | `Streak +/−` 调拖影上限 |
| 其他 | `Threshold` 加大速度死区：动得慢的部分保持清晰，只模糊快速动作 |
| 其他 | `Force Cut` 强制切镜，`Keep Camera` 强制沿用相机历史 |

全部表情为 0 时沿用 `Settings.fxh` 和附件 Si。快门角按 30 fps 的一帧计算，与导出帧率无关：30 和 60 fps 导出的拖影长度相同。P1 轮廓外拖尾和描边修正不在控制器里，用 `Settings.fxh` 的 `MB_EXTEND_FOREGROUND`、`MB_OUTLINE_MOTION` 开关。参数范围和注册说明见 [参数手册](docs/PARAMETERS.md#pmx-实时控制器)。

## 参数

修改 `src/Settings.fxh` 后重载效果。参数范围、联动、调试视图和载入速度见 [参数手册](docs/PARAMETERS.md)。

| 参数 | 默认 | 作用 |
|---|---|---|
| `MB_SHUTTER_ANGLE` | 180° | 居中快门近似，范围 0–360°，按 30 fps 的一帧计算 |
| `MB_MOTION_SCALE` | 1.3 | 与附件 Si 相乘的强度倍率 |
| `MB_QUALITY` | 1 | 0、1、2 按拖影长度分配轨迹样本，间隔 4、2、1 px；3 为固定 16 个样本（与 0.2.0 相同，长拖影呈残影状） |
| `MB_SCALE_STREAK_WITH_HEIGHT` | 1 | 1 按画面高度换算拖影上限和死区，0 使用固定输出像素 |
| `MB_MAX_STREAK` | 64 px | 以 1080p 为基准的最大拖影长度，中心两侧各一半 |
| `MB_SPEED_THRESHOLD` | 3 px | 以 1080p 为基准的速度死区。每个像素的拖影先减去这个长度，慢的部分保持清晰 |
| `MB_DEPTH_TOLERANCE` | 0.045 | 调低可更严格地排除跨深度层样本 |
| `MB_MIN_FRAME_GAP` | 0.0001 s | 排除重复时间戳和浮点误差 |
| `MB_MAX_FRAME_GAP` | 0.1001 s | 允许约 10 fps 的预览间隔，超出后回到当帧原色 |
| `MB_CUT_ANGLE_COS` | 0.766 | 相邻渲染帧间约 40° 的切镜保护 |
| `MB_CUT_SCREEN_HEIGHT` | 0.05 | 屏幕位移超过画面高度的比例（五点中值，镜头朝向不变时另查 7×5 个点），0 关闭位移判定 |
| `MB_CUT_SPEED_RATIO` | 3.0 | 位移超过阈值时，还需要超过上一帧屏幕速度的倍数 |
| `MB_CLEAR_RGBA` | 1, 1, 1, 0 | 场景捕获的初始底色 |
| `MB_TRAIL_ALPHA` | 0 | 1 试用带覆盖率的透明拖尾，输出预乘 RGBA |
| `MB_TRANSLUCENT_MOTION` | 0 | 1 试用发梢等普通 Alpha 材质的同层模糊 |
| `MB_DEBUG` | 0 | 0 成片、1 原色、2 快门位移、3 深度、4 覆盖与速度来源 |
| `MB_EXTEND_FOREGROUND` | 1 | 1 启用前景拖尾扩张，0 使用 P0 的轮廓内采样 |
| `MB_TRAIL_SPREAD` | 0.35 | 轮廓外拖尾对方向偏差的容忍度，避免描边碎成点；0 回到 0.2.0 |
| `MB_LINEAR_COLOR` | 1 | 轮廓内模糊颜色线性过滤，斜的细描边均匀变淡；0 回到 0.2.0 |
| `MB_SAMPLE_JITTER` | 1 | 1 沿拖影方向微移采样点，把规则的残影条纹打散成细颗粒；0 为规则的残影状拖影 |
| `MB_OUTLINE_SEARCH` | 3 | 描边像素向外找模型表面借速度的距离（px），避免宽描边外侧保持清晰、成为虚线 |
| `MB_OUTLINE_FRINGE` | 1 | 描边的抗锯齿柔边跟着描边模糊，避免运动轮廓上留下深色虚点；0 回到 0.2.0 |
| `MB_EDGE_BACKGROUND` | 1 | 运动轮廓内侧透出背景，轮廓两侧连续虚化；0 回到 0.2.0 的实心轮廓 |
| `MB_OUTLINE_MOTION` | 1 | P1 启用原生描边和细后处理描边的速度修正。设为 0 可保留 P1 拖尾并单独对照描边处理 |
| `MB_AUTO_MODEL_MOTION` | 1 | 为 PMX／PMD 默认启用顶点历史；设为 0 时默认只计算镜头运动，可通过 `GeometryData` 为角色手动开启 |
| `MB_ACCESSORY_MOTION` | 0 | 1 为移动的 `.x` 附件启用矩阵历史，固定镜头也能试用附件自身拖影 |
| `MB_HISTORY_SIZE` | 512 | 方形顶点图集边长，容量为边长的平方 |
| `MB_KEEP_OBJECT_MOTION_ON_CUT` | 1 | 使用世界空间顶点历史，切镜帧背景回到原色、角色保留自身动作模糊；0 为切镜帧整幅原色 |
| `MB_TELEPORT_DISTANCE` | 50.0 | 世界空间顶点历史或附件矩阵历史开启时，超过此世界距离的顶点回退到镜头速度，0 关闭检查 |

调试 2 中，R 与 G 是有符号水平、垂直位移，B 是长度。调试 4 中，蓝色为相机路径，绿色为有效顶点历史，红色为识别到的半透明或加法材质，黄色为辅助缓冲捕获的原生描边，黑色为无辅助几何。

## 已知限制

- 相同时间重复绘制、倒放、超过阈值的跳帧和大幅镜头变化会回到当帧。暂停截图可能只看到清晰画面。导出可留一帧预卷，小幅硬切可将该帧的 Si 设为 0。
- 原生描边从相邻同深度表面取得运动。对已合成进场景颜色的细后处理描边，只识别位于前后景交界处、两侧都更亮的单像素暗线。宽线、浅色线以及在本效果之后生成的描边可能仍然清晰。地面影、第三方粒子及修改过顶点位置的材质也可能与辅助深度产生覆盖差异。
- 默认保留半透明材质的捕获值。`MB_TRANSLUCENT_MOTION=1` 可试用普通 Alpha 材质的模糊。`MB_TRAIL_ALPHA=1` 可试用透明底拖尾，宿主捕获与导出链仍待实测。
- P1 每个区域使用一个主速度方向。两个快速物体在同一区域交叉运动时，较短的拖尾可能被漏采。顶点图集超限时回退至相机模式，两张默认图集合计约 8 MiB／对象，另有深度表面。
- 详细验证、基线和下一阶段见 [docs/VALIDATION.md](docs/VALIDATION.md)。
