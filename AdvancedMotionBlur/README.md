# AdvancedMotionBlur 0.3.0

AdvancedMotionBlur 是 CicloO 制作的 MikuMikuEffect 动态模糊效果，适用于 MikuMikuDance 9.32 x64 和 MME 0.37 x64。它可同时处理镜头运动和角色自身动作，快动作的拖影可以延伸到轮廓外。

## 下载与载入

配布包发布后可从 [GitHub Releases](https://github.com/CicloO/mmecc/releases) 下载。完整解压后，将 `AdvancedMotionBlur.x` 作为附件载入 MMD，在附件绘制顺序中放在舞台等场景附件之后。附件的 **Si** 默认为 1，设为 0 可关掉模糊。请连续播放或导出查看效果。

从仓库源码试用时，运行文件位于 `src/`。使用条件、安装和旧控制器升级说明见 [Readme.txt](src/Readme.txt)。

## 调整效果

- 将 `AdvancedMotionBlurController.pmx` 作为模型载入，选中 **AMB Controller**。可用表情调整强度、快门和拖影上限，也可以注册关键帧。
- 只需要角色动作模糊时，将控制器的 `Camera Off` 设为 0.5 或更高。想单独关掉某个模型的镜头模糊时，在 MME 效果分配的 `GeometryData` 页为该模型分配 `ObjectMotion.fx`。
- 修改 `Settings.fxh` 后重载效果。想恢复规则的残影，可把 `MB_SAMPLE_JITTER` 设为 0。

详见 [参数手册](docs/PARAMETERS.md) 和 [更新记录](CHANGELOG.md)。
