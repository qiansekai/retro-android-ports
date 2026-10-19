# 中文译文基准（i18n baseline）

本仓库的英文文档来自上游 [pukikiko/retro-android-ports](https://github.com/pukikiko/retro-android-ports)。下表记录每份译文依据的英文快照，以及该英文源在此之后是否被上游改动。

- 译文基准 commit：`569c304`（2026-10-17）
- 上游随后做了 libhyb 重构（11 个 commit，截至 `69be3d0`，2026-10-19），一批英文文档已变化，对应译文需要增量更新。

| 译文 | 英文源 | 上游自基准起 |
| --- | --- | --- |
| [AGENTS.zh-CN.md](../../AGENTS.zh-CN.md) | `AGENTS.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../../README.zh-CN.md) | `README.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../../devices/cooper/README.zh-CN.md) | `devices/cooper/README.md` | 无 |
| [README.zh-CN.md](../../devices/maple/README.zh-CN.md) | `devices/maple/README.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../../devices/poplar/README.zh-CN.md) | `devices/poplar/README.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../../devices/raphael/README.zh-CN.md) | `devices/raphael/README.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../advanced/README.zh-CN.md) | `docs/advanced/README.md` | **有改动**，需增量更新 |
| [build-server.zh-CN.md](../advanced/build-server.zh-CN.md) | `docs/advanced/build-server.md` | **有改动**，需增量更新 |
| [donut.zh-CN.md](../advanced/build/donut.zh-CN.md) | `docs/advanced/build/donut.md` | 无 |
| [kitkat.zh-CN.md](../advanced/build/kitkat.zh-CN.md) | `docs/advanced/build/kitkat.md` | **有改动**，需增量更新 |
| [charquirks-mapping.zh-CN.md](../advanced/charquirks-mapping.zh-CN.md) | `docs/advanced/charquirks-mapping.md` | **有改动**，需增量更新 |
| [poplar-kitkat-gpu-fixes.zh-CN.md](../advanced/poplar-kitkat-gpu-fixes.zh-CN.md) | `docs/advanced/poplar-kitkat-gpu-fixes.md` | **有改动**，需增量更新 |
| [donut.zh-CN.md](../advanced/porting-notes/donut.zh-CN.md) | `docs/advanced/porting-notes/donut.md` | **有改动**，需增量更新 |
| [kitkat.zh-CN.md](../advanced/porting-notes/kitkat.zh-CN.md) | `docs/advanced/porting-notes/kitkat.md` | **有改动**，需增量更新 |
| [glrenderd.zh-CN.md](../advanced/software/glrenderd.zh-CN.md) | `docs/advanced/software/glrenderd.md` | 源已被上游删除（libhyb 取代），译文仅存档 |
| [mkbootimg-cooper.zh-CN.md](../advanced/software/mkbootimg-cooper.zh-CN.md) | `docs/advanced/software/mkbootimg-cooper.md` | 无 |
| [vtouch.zh-CN.md](../advanced/software/vtouch.zh-CN.md) | `docs/advanced/software/vtouch.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../devices/cooper/README.zh-CN.md) | `docs/devices/cooper/README.md` | 无 |
| [quirks.zh-CN.md](../devices/cooper/quirks.zh-CN.md) | `docs/devices/cooper/quirks.md` | 无 |
| [README.zh-CN.md](../devices/maple/README.zh-CN.md) | `docs/devices/maple/README.md` | **有改动**，需增量更新 |
| [quirks.zh-CN.md](../devices/maple/quirks.zh-CN.md) | `docs/devices/maple/quirks.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../devices/poplar/README.zh-CN.md) | `docs/devices/poplar/README.md` | **有改动**，需增量更新 |
| [quirks.zh-CN.md](../devices/poplar/quirks.zh-CN.md) | `docs/devices/poplar/quirks.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../../patches/donut/README.zh-CN.md) | `patches/donut/README.md` | **有改动**，需增量更新 |
| [README.zh-CN.md](../../patches/kitkat/README.zh-CN.md) | `patches/kitkat/README.md` | **有改动**，需增量更新 |

更新流程：`git diff 569c304..HEAD -- <英文源>` 看差异 → 只改译文对应段落 → 把本表状态改回「无」并追加新的基准 commit。
