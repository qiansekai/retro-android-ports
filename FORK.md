# 本 fork 说明（Redmi K20 Pro / K40）

这是 [pukikiko/retro-android-ports](https://github.com/pukikiko/retro-android-ports) 的公开 fork，保留上游全部内容，在其之上加入我们自己的设备移植。上游文档仍为英文；fork 专属文档用中文。

## 与上游的差异（全部落在独立路径，目的是让 `git merge upstream/main` 保持可快进）

| 路径 | 内容 | 上游状态 |
| --- | --- | --- |
| `devices/raphael/` | Redmi K20 Pro（raphael，SM8150）KitKat 设备树 | 无此设备 |
| `docs/devices/raphael/` | K20 Pro 设备页 + 怪癖台账 | 无 |
| `tools/raphael/glrenderd/` | raphael 的 GL 渲染栈（DRM/KMS presenter，无 fbdev） | 上游 2026-10-19 改用 `tools/libhyb/`，删除了 `tools/glrenderd/` |
| `patches/kitkat/raphael/` | raphael 依赖的 5 个 glrenderd 相关 AOSP patch | 上游已删除同名文件 |
| `scripts/sync-device-tree.sh` | 新增 `raphael)` 分支（3 行） | 上游只改 rsync 行，自动合并 |
| `README.md` | 顶部 fork 说明 | 唯一预期冲突点 |

## 为什么 glrenderd 在 `tools/raphael/`

上游用 libhyb（进程内 Adreno 驱动 + 64 位 `fbpresentd`）取代了 glrenderd。但 raphael 没有 fbdev，KitKat 的 SurfaceFlinger 靠 `hwcomposer.raphael`（HWC 1.1）把帧交给 `fbDev->post`，最终由 glrenderd 的 DRM/KMS 后端（dumb buffer → dma-buf mmap → ADDFB2 → PAGE_FLIP）上屏。所以整棵树搬到我们自己的路径下继续维护，与上游删除互不干扰。后续若把 raphael 迁到 libhyb，这个目录可以再删。

## 同步上游

```sh
git fetch upstream
git merge upstream/main
```

预期冲突：只有 `README.md` 顶部的 fork 说明（上游高频改 roadmap）。若 `scripts/sync-device-tree.sh` 的 case 列表被上游改动，手工保留 `raphael)` 行即可。

## 设备清单

- **Redmi K20 Pro**（`raphael`，SM8150）：KitKat 4.4.4 已点亮（DRM PAGE_FLIP、硬件 GLES 3.2）；Froyo 2.2 已打通（全屏、串口投屏、全局导航栏）；Gingerbread 2.3 仅做可行性后暂停。
- **Redmi K40**（`alioth`，SM8250）：尚未开始，预留 `devices/alioth/`。

## 已知未解项

- raphael KitKat：真手指触摸依赖 goodix 固件，滑动中偶发 `touch_num=0` 被协议 A 解析成抬手（Froyo 侧已弃疗，KitKat 侧待验）。
- raphael Froyo：netd 卡在启动、vold/netd 偶发 abort、RTC 未对时。
- cust 分区（sda30，1 GB raw）里现在装的是 Froyo 的 system；回 KitKat 需重建并重刷。
