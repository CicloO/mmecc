# Claude 协作入口

本文件用于 Codex 与 Claude 在 GitHub 仓库中共享项目约定。先阅读本文件，再按任务阅读 `README.md` 与 `docs/VALIDATION.md`；实现、参数和验证结论以仓库当前内容为准。

## 项目范围

- 这是面向原版 MikuMikuDance 9.32 x64 与 MME 0.37 的独立动态模糊原型。
- 当前阶段为 P1。`docs/VALIDATION.md` 区分离线/隔离环境证据、原生 MMD 对照及待验收项；不要把编译、模拟器加载或数学测试描述为实机视觉验收。
- 调整着色器或参数时，检查对照模式、相机运动、骨骼运动、深度边缘与透明输出是否受影响，并更新相应验证记录。

## 协作约定

- 先查看 `git status`、当前分支和近期提交；保留已有改动，不覆盖或重置他人的工作。
- 在独立分支或明确分配的文件范围内工作。开始同一任务前，通过 GitHub issue/PR 或聊天说明目标、涉及文件和验证方式。
- 交接时记录：改动摘要、验证命令与结果、未完成项、需要另一位协作者检查的内容。提交与推送前说明具体改动。
- 未实际运行的验证标记为“未运行”；记录运行环境。不要删除文件或验证素材，除非任务明确要求。
- 仓库内容和提交历史是 Codex/Claude 共同上下文的持久来源；项目知识库若不可用，继续以这些文档交接，不声称记忆已同步。

## 项目文档

- `README.md`：安装、目录、参数和使用说明。
- `docs/VALIDATION.md`：技术依据、已有证据、复现场景和后续计划。
- `src/`：运行文件（`.x`、`.fx`、`.fxh` 须同目录）和 PMX 控制器。
- `tools/build_controller.py`：重新生成 PMX 控制器；修改表情名时同步 `src/Controller.fxh`。
- `tools/fxc_matrix.ps1`：FXC 编译矩阵（各开关组合 × 5 个效果）；`tools/d3dx_compile_time.py`：用 MME 实际使用的 `d3dx9_43` 计编译时间，载入速度以它为准。
- `docs/HANDOFF.md`：当前的交接单（保护基准版本的做法、任务顺序、检查方法和已知的坑）。
- `docs/PARAMETERS.md`：参数手册与控制器表情说明。
- `docs/ROADMAP.md`：后续计划书（画面问题清单、分阶段方案和验收标准）。
- `docs/validation/`、`fixtures/`：验证截图与测试场景。
- `dist/`：各版本 zip，只存在本地，不入库也不上传。
- `CHANGELOG.md`：各版本改动。

## 版本与发布

- 版本号写在 `README.md` 标题和 `CHANGELOG.md`。标签格式 `AdvancedMotionBlur/v<版本>`，一个仓库多个 MME，前缀用来区分。
- 仓库布局：`main` 只放各 MME 的最新发布版，一个 MME 一个子文件夹（本 MME 是 `AdvancedMotionBlur/`）；开发中的版本放在以 MME 命名的分支（本 MME 是 `AdvancedMotionBlur` 分支）。日常开发只在该分支提交，不直接改 `main`。
- 发布：在开发分支更新 README 标题与 CHANGELOG 并提交，把已提交内容并入 `main`（只动本 MME 的子文件夹），在 `main` 上打标签，然后在 `H:\Coding\mmecc` 运行：

```bash
git switch main
git merge --no-ff AdvancedMotionBlur -m "AdvancedMotionBlur 0.2.0"
git tag -a AdvancedMotionBlur/v0.2.0 -m "AdvancedMotionBlur 0.2.0"
git archive --format=zip --prefix=MMD-AdvancedMotionBlur/ -o AdvancedMotionBlur/dist/MMD-AdvancedMotionBlur-0.2.0.zip AdvancedMotionBlur/v0.2.0:AdvancedMotionBlur README.md CHANGELOG.md src docs fixtures
git push origin main AdvancedMotionBlur/v0.2.0
git switch AdvancedMotionBlur
```

- 不创建 GitHub Release，zip 只保存在本地 `dist/`。zip 只含已提交的 `README.md`、`CHANGELOG.md`、`src/`、`docs/`、`fixtures/`，不含 `CLAUDE.md`、`tools/` 和本地测试文件。推送标签前先说明内容并得到用户确认。
