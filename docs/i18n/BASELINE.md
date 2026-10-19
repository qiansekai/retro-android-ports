# 中文译文基准（i18n baseline）

本仓库的英文文档来自上游 [pukikiko/retro-android-ports](https://github.com/pukikiko/retro-android-ports)。下表记录每份译文依据的英文快照，以及该英文源在此之后是否被改动。

- 译文基准 commit：`6f648f6`（上游 2026-10-19，已由 fork 的 `main` 合并）
- 首次译制基准为 `569c304`；2026-10-19 依 `569c304..69be3d0` 的差异做了增量更新：修订 19 篇、新译 2 篇（libhyb、taimen-kitkat-mapping）、1 篇存档（glrenderd，上游已删源）。
- 当前状态：过期 0 篇，存档 1 篇。

| 译文 | 英文源 | 上游自基准起 |
| --- | --- | --- |
| [AGENTS.zh-CN.md](../../AGENTS.zh-CN.md) | `AGENTS.md` | 无 |
| [README.zh-CN.md](../../README.zh-CN.md) | `README.md` | 无 |
| [README.zh-CN.md](../../devices/cooper/README.zh-CN.md) | `devices/cooper/README.md` | 无 |
| [README.zh-CN.md](../../devices/maple/README.zh-CN.md) | `devices/maple/README.md` | 无 |
| [README.zh-CN.md](../../devices/poplar/README.zh-CN.md) | `devices/poplar/README.md` | 无 |
| [README.zh-CN.md](../../devices/raphael/README.zh-CN.md) | `devices/raphael/README.md` | 无 |
| [README.zh-CN.md](../advanced/README.zh-CN.md) | `docs/advanced/README.md` | 无 |
| [build-server.zh-CN.md](../advanced/build-server.zh-CN.md) | `docs/advanced/build-server.md` | 无 |
| [donut.zh-CN.md](../advanced/build/donut.zh-CN.md) | `docs/advanced/build/donut.md` | 无 |
| [kitkat.zh-CN.md](../advanced/build/kitkat.zh-CN.md) | `docs/advanced/build/kitkat.md` | 无 |
| [charquirks-mapping.zh-CN.md](../advanced/charquirks-mapping.zh-CN.md) | `docs/advanced/charquirks-mapping.md` | 无 |
| [poplar-kitkat-gpu-fixes.zh-CN.md](../advanced/poplar-kitkat-gpu-fixes.zh-CN.md) | `docs/advanced/poplar-kitkat-gpu-fixes.md` | 无 |
| [donut.zh-CN.md](../advanced/porting-notes/donut.zh-CN.md) | `docs/advanced/porting-notes/donut.md` | 无 |
| [kitkat.zh-CN.md](../advanced/porting-notes/kitkat.zh-CN.md) | `docs/advanced/porting-notes/kitkat.md` | 无 |
| [glrenderd.zh-CN.md](../advanced/software/glrenderd.zh-CN.md) | `docs/advanced/software/glrenderd.md` | 源已被上游删除（libhyb 取代），译文仅存档 |
| [mkbootimg-cooper.zh-CN.md](../advanced/software/mkbootimg-cooper.zh-CN.md) | `docs/advanced/software/mkbootimg-cooper.md` | 无 |
| [vtouch.zh-CN.md](../advanced/software/vtouch.zh-CN.md) | `docs/advanced/software/vtouch.md` | 无 |
| [README.zh-CN.md](../devices/cooper/README.zh-CN.md) | `docs/devices/cooper/README.md` | 无 |
| [quirks.zh-CN.md](../devices/cooper/quirks.zh-CN.md) | `docs/devices/cooper/quirks.md` | 无 |
| [README.zh-CN.md](../devices/maple/README.zh-CN.md) | `docs/devices/maple/README.md` | 无 |
| [quirks.zh-CN.md](../devices/maple/quirks.zh-CN.md) | `docs/devices/maple/quirks.md` | 无 |
| [README.zh-CN.md](../devices/poplar/README.zh-CN.md) | `docs/devices/poplar/README.md` | 无 |
| [quirks.zh-CN.md](../devices/poplar/quirks.zh-CN.md) | `docs/devices/poplar/quirks.md` | 无 |
| [README.zh-CN.md](../../patches/donut/README.zh-CN.md) | `patches/donut/README.md` | 无 |
| [README.zh-CN.md](../../patches/kitkat/README.zh-CN.md) | `patches/kitkat/README.md` | 无 |

更新流程：`git diff 6f648f6..HEAD -- <英文源>` 看差异 → 只改译文对应段落 → 把本表状态改回「无」，并把顶部基准 commit 换成新的英文快照。
