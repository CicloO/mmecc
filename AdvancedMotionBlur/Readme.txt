AdvancedMotionBlur  ver.0.3.0
作者  CicloO

■ 简介

适用于 MikuMikuEffect 的动态模糊，参考了游戏引擎和Eevee里的运动模糊效果进行实现。
支持镜头运动和模型自身动作，并提供fx分配。

■ 运行环境

MikuMikuDance 9.32 x64、MikuMikuEffect 0.37 x64
DirectX 9.0c（June 2010）运行库

■ 使用方法

1. 展开整个 ZIP，把 AdvancedMotionBlur.x 作为附件载入。
   保留同目录的 .fx 和 .fxh 文件。
2. 在附件绘制顺序中，把效果放在舞台等场景附件之后。
3. 连续播放或导出查看。Si 为 1 时是标准强度，设为 0 可关掉模糊。

暂停或跳帧后可能显示清晰画面。导出时可从所需片段的前一帧开始，留出上一帧历史。
使用时请停用其他动态模糊效果。

■ 控制器（可选）

把 AdvancedMotionBlurController.pmx 作为模型载入并选中 AMB Controller。
请保留原文件名。表情权重为 0–1，全部为 0 时沿用附件 Si 和 Settings.fxh。
可按帧注册表情。

  眉（整体）  Strength + / -   增减强度
              Shutter + / -    增减快门角，影响拖影长度
  眼（拖影）  Streak + / -     增减拖影长度上限
              Threshold        提高慢动作保持清晰的阈值
  口（镜头）  Camera + / -     只增减镜头运动造成的模糊，角色自身动作不变；
                               Camera - 为 1 时只剩角色自身动作的模糊
  其他        Force Cut        按切镜处理当前帧
              Keep Camera      沿用镜头运动历史
              Jitter Off       颗粒状拖影改为规则的残影状拖影

Force Cut、Keep Camera、Jitter Off 在权重达到 0.5 时生效。
Force Cut 优先于 Keep Camera。镜头扫得很快、整幅画面糊得太重时，
可在那一段注册 Camera -。

■ 按对象设置模糊

在 MME 效果分配的 GeometryData 页，对整个对象的行分配效果。保留 Main 页的材质。

  MotionGeometry.fx  镜头运动和模型动作（PMX／PMD 默认）
  DepthVelocity.fx   镜头运动（场景附件默认）
  ObjectMotion.fx    仅模型自身动作
  NoMotionBlur.fx    对象保持清晰，保留其深度遮挡

NoMotionBlur.fx 不记录该对象的顶点历史，也不计算它的拖影速度。分配到
GeometryData 页即可，Main 页保留原材质。

要让指定的效果附件默认使用 NoMotionBlur.fx，可在 Settings.fxh 里按文件名设置
MB_EXCLUDED_ACCESSORY_RULES，例如 "MyEffect.x = NoMotionBlur.fx;"。
多个文件用分号隔开。重载后，已有手动映射的工程仍需检查 GeometryData。

全场景只保留模型动作模糊时，可把 Camera - 设为 1，或将 Settings.fxh 中的
MB_CAMERA_MOTION 设为 0。

■ 常用设置

修改 Settings.fxh 并保存后，重新载入 AdvancedMotionBlur.x。

  MB_SHUTTER_ANGLE    快门角，默认 180°，以 30 fps 的一帧为基准。
  MB_MAX_STREAK       拖影长度上限，默认 64 px，以 1080p 为基准。
  MB_SPEED_THRESHOLD  速度死区，默认 3 px，以 1080p 为基准。
  MB_SAMPLE_JITTER    1 为采样抖动（默认），0 为固定采样。也可用 Jitter Off 表情按段切换。
  MB_TRANSLUCENT_MOTION  1 时半透明和加法（发光）材质也一起模糊（默认），0 保持清晰。
  MB_LINEAR_LIGHT     1 在线性光空间混合拖影（默认），亮色拖过暗处更自然。
  MB_QUALITY          0／1／2 为低／中／高（默认 1）；3／4／5 为固定 8／16／24 点采样。

全部参数及附加选项见 docs/PARAMETERS.md。

■ 升级旧工程

新版控制器增加了表情。请先备份旧工程，在旧版环境中移除旧控制器并另存 PMM，
再载入新版控制器。原控制器的表情关键帧需重新注册。直接适配可能导致 MMD 崩溃。

在本效果之后绘制的描边可能保持清晰。单个模型超出默认 512×512 顶点历史容量时，
会回退到镜头运动路径。

■ 使用条件

・个人和商业视频均可免费使用，无需事先联系作者。
・署名可选。若署名，请写「CicloO」或「AdvancedMotionBlur / CicloO」。
・允许修改后自用。禁止再配布，请直接在GitHub上pr或联系作者。
・作者不承担因使用本效果产生的责任。

■ 更新记录

0.3.0  新增仅模型动作模糊和 Camera Off 表情，改进切镜处理，默认开启采样抖动，
       修正快速前景附近背景拖影成块消失的问题。详见 docs/CHANGELOG.md。
