# AGENTS.md

> 中文译文。英文原文见 [AGENTS.md](AGENTS.md)。技术名词、代码、路径、命令与日志一律保留原文。

## 本机环境覆盖（未跟踪，可选）

- 若本文件旁存在 `AGENTS.local.md`，读它 —— 它保存单实例私有信息（构建服务器主机/用户/密码、本地路径），并覆盖通用文档。它被 gitignore，全新 clone 中不存在，所以绝不依赖它，也绝不提交它。

## 文档是移植的一部分

在同一个变更里更新相关文档，与任何移植工作一起做。
遇到坑（构建失败、启动卡住、静默行为异常、刷机/打包陷阱、工具骗了你）就记录下来 —— 不要让知识只留在聊天里。

在任何上下文压缩之前，把待写的文档更新落盘：被压缩的会话绝不该是某个坑的唯一记录处。如果压缩临近而文档已过期，先更新文档。

写到哪里：

- 可跨同版本设备复用的通用经验：`docs/advanced/porting-notes/<release>.md`（Donut：`donut.md`，KitKat：`kitkat.md`）。新版本新开文件，并在 `docs/advanced/README.md` 注册。
- 构建配方（源码获取、补丁顺序、打包、刷机），逐版本：`docs/advanced/build/<release>.md`。构建主机/容器配方变更：`docs/advanced/build-server.md` 或 `containers/<release>/`。
- 项目自研软件/驱动说明：`docs/advanced/software/<tool>.md`（vtouch、glrenderd、mkbootimg-cooper）。新工具 ⇒ 新页面，从 `docs/advanced/README.md` 链接。
- 硬件特定事实、地址、分区布局、已验证修复、未解缺口：`docs/devices/<codename>/quirks.md`。
- 行为/状态变化（新的启动状态、可用/不可用功能）：设备主页 `docs/devices/<codename>/README.md`、README 的 Ports 表、以及 `README.md` 的 Roadmap。
- 补丁集变更：`patches/<release>/README.md`，与 `patches/<release>/` 下的 diff（+ `files/` overlay）放在一起。
- 把别的移植的文档/方案映射到我们这边的对照说明（poplar/CHARQUIRKS 一类包）：`docs/advanced/` 下的参考页（例如 `charquirks-mapping.md`）。

新设备 ⇒ `docs/devices/<codename>/README.md`（照片、描述、逐版本状态矩阵、链接）+ `docs/devices/<codename>/quirks.md`，README 设备表加一行，并在 `docs/advanced/README.md` 中该版本移植笔记表的「Ported to」列补一项。

不确定算通用还是设备特定？写进设备怪癖页，再从实战手册链过去，而不是反过来。

## 沿用既有文档格式

遵循你正在编辑的文件的形态：

- 标题：设备主页 `# <Full device name> (<codename>)`；设备怪癖页 `# <codename> quirks (<full device name>)`；实战手册 `# Porting notes: <release> on newer hardware`；构建/软件页 `# <what it is>`。然后 2-4 行范围说明：本文件覆盖哪个版本/设备/工具，并链接同级文档（设备页 → 怪癖页 + 实战手册 + 构建指南；实战手册 → 构建指南 + 设备怪癖页 + 进阶索引）。Hub 页就是 `README.md`，这样在 GitHub 上浏览目录时能直接渲染：`docs/advanced/README.md`、`docs/devices/<codename>/README.md`。
- 按子系统分 `##` 节（`Source & toolchain`、`Platform specifics`、`Field lessons` 等）。只有在没有合适归属时才加新节。
- 要点用**粗体引导词**起头（`- **Sparse images bite twice.** ...`），然后按 症状 → 根因 → 修复 展开，给出确切文件路径（`system/core/init/builtins.c`、`devices/maple/kitkat/...`）、确切的错误字符串 / ioctl 号 / 日志行，以及修好它的命令或补丁。
- 讲验证，不讲断言：说明是怎么确认的（设备上的日期如 `verified 2026-10-15`、maple 的 `TEST N` 序列、刷机后的哈希回读、`dmesg`/fb0 解码证据）。把未测试的预测标出来（`TODO`、`verify-me`、`to fill in once built`）—— 见 `docs/advanced/porting-notes/kitkat.md` 的 Container gotchas 与 `docs/devices/maple/quirks.md` 的阻塞项。
- 同平台姊妹设备出现分歧时明确记录（例如 msm8998 移植里 `FBIOPAN_DISPLAY` vs `FBIOPUT_VSCREENINFO`）：各自在哪个设备上验证过，并在目标设备上重新验证 —— 不要从一个设备外推。
- 交叉链接保持相对路径（`[playbook](../porting-notes/donut.md)`、`[quirks](quirks.md)`）；新增文档、设备或版本时，保持 README 的 Ports 表、`docs/advanced/README.md` 索引以及各设备页的链接/状态一致。

不做顺手重排/重格式化。保持你改的这份文件的行宽、要点风格与章节顺序。
