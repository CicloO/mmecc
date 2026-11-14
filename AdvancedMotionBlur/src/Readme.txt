AdvancedMotionBlur  ver.0.3.0
制作 / 作者  CicloO

■ 概要 / 简介

MikuMikuEffect 用のモーションブラーです。カメラの動きとモデル自身の動きに
対応します。カメラを固定していても、動いているモデルにブラーがかかります。

适用于 MikuMikuEffect 的动态模糊。支持镜头运动和模型自身动作。
固定镜头下，挥手、转身等动作也有拖影。

■ 動作環境 / 运行环境

MikuMikuDance 9.32 x64、MikuMikuEffect 0.37 x64
DirectX 9.0c（June 2010）ランタイム / 运行库

■ 使い方 / 使用方法

1. ZIP を展開し、AdvancedMotionBlur.x をアクセサリとして読み込みます。
   展开整个 ZIP，把 AdvancedMotionBlur.x 作为附件载入。保留同目录的 .fx 和 .fxh。
2. アクセサリの描画順で、ステージなどより後に配置します。
   在附件绘制顺序中，把效果放在舞台等场景附件之后。
3. 再生して効果を確認します。Si は 1 が標準、0 でブラーを無効にします。
   连续播放或导出查看。Si 为 1 时是标准强度，设为 0 可关掉模糊。

停止中やフレーム移動の直後はブラーが表示されないことがあります。
動画出力は必要な区間の 1 フレーム前から始めると、先頭にもブラーがかかります。
ほかのモーションブラーエフェクトとの併用は避けてください。

暂停或跳帧后可能显示清晰画面。导出时可从所需片段的前一帧开始，留出上一帧历史。
使用时请停用其他动态模糊效果。

■ コントローラー / 控制器

AdvancedMotionBlurController.pmx をモデルとして読み込み、AMB Controller を
選びます。ファイル名は変更しないでください。表情はキー登録できます。
すべての表情が 0 の場合は、Si と Settings.fxh の設定が使われます。

把 AdvancedMotionBlurController.pmx 作为模型载入并选中 AMB Controller。
请保留原文件名。表情权重为 0–1，全部为 0 时沿用附件 Si 和 Settings.fxh。
可按帧注册表情。控制器可选。

  眉       Strength + / -   強さ / 强度
  目・眼   Shutter + / -    シャッター角 / 快门角
  口       Streak + / -     ブラーの最大長 / 拖影长度上限
  その他   Threshold        低速時のブラーを抑える / 提高慢动作保持清晰的阈值
           Force Cut        カットを指定 / 按切镜处理当前帧
           Keep Camera      カメラの履歴を維持 / 沿用镜头运动历史
           Camera Off       カメラのブラーを無効化 / 关闭镜头模糊

Force Cut・Keep Camera・Camera Off は 0.5 以上で有効です。
最后三项在权重达到 0.5 时生效。Force Cut 优先于 Keep Camera。

■ 効果割当 / 按对象设置模糊

MMEffect の「エフェクト割当」で GeometryData タブを開き、対象の行全体に
割り当てます。Main タブの材質はそのまま使います。
在 MME 效果分配的 GeometryData 页，对整个对象的行分配效果。保留 Main 页的材质。

  MotionGeometry.fx  カメラとモデルの動き / 镜头运动和模型动作（PMX／PMD 默认）
  DepthVelocity.fx   カメラの動き / 镜头运动（场景附件默认）
  ObjectMotion.fx    モデル自身の動き / 仅模型自身动作

画面全体でカメラのブラーを無効にするには、Camera Off を使用するか、
Settings.fxh の MB_CAMERA_MOTION を 0 にします。
全场景只保留模型动作模糊时，可使用 Camera Off，或将 MB_CAMERA_MOTION 设为 0。

■ 設定 / 常用设置

Settings.fxh を編集した後、AdvancedMotionBlur.x を読み込み直してください。
修改 Settings.fxh 并保存后，重新载入 AdvancedMotionBlur.x。

  MB_SHUTTER_ANGLE    シャッター角 / 快门角。默认 180°，以 30 fps 的一帧为基准。
  MB_MAX_STREAK       最大長 / 拖影长度上限。默认 64 px，以 1080p 为基准。
  MB_SPEED_THRESHOLD  低速域のしきい値 / 速度死区。默认 3 px，以 1080p 为基准。
  MB_SAMPLE_JITTER    1 = サンプルをずらす / 采样抖动（默认），0 = 固定采样。
  MB_QUALITY          0／1／2 为低／中／高（默认 1），3 为固定 16 点采样。

全部参数及附加选项见 docs/PARAMETERS.md。

■ 旧バージョンからの更新 / 升级旧工程

旧版のコントローラーが入っている PMM はバックアップしてください。
旧環境でコントローラーを外し、別名で保存してから新版を読み込んでください。
コントローラーの表情キーは登録し直す必要があります。

新版控制器增加了表情。请先备份旧工程，在旧版环境中移除旧控制器并另存 PMM，
再载入新版控制器。原控制器的表情关键帧需重新注册。直接适配可能导致 MMD 崩溃。

在本效果之后绘制的描边可能保持清晰。单个模型超出默认 512×512 顶点历史容量时，
会回退到镜头运动路径。

■ 利用規約 / 使用条件

・個人利用・商用動画での利用は無料です。事前連絡は不要です。
・クレジット表記は任意です。表記する場合は「AdvancedMotionBlur / CicloO」。
・自分で使うための改変は可能です。改変の有無を問わず再配布は禁止です。
・本エフェクトの使用により生じた問題について、作者は責任を負いません。

・个人和商业视频均可免费使用，无需事先联系作者。
・署名可选。若署名，请写「AdvancedMotionBlur / CicloO」。
・允许修改后自用。原版和修改版均禁止再分发。
・作者不承担因使用本效果产生的责任。

■ 更新履歴 / 更新记录

0.3.0  新增仅模型动作模糊和 Camera Off 表情，改进切镜处理，默认开启采样抖动，
       修正快速前景附近背景拖影成块消失的问题。详见 CHANGELOG.md。
