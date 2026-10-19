# patches/donut

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

本移植对干净 AOSP Donut（`android-1.6_r2`）检出所做的改动。
分步构建：[`docs/advanced/build/donut.zh-CN.md`](../../docs/advanced/build/donut.zh-CN.md)；
实战教训：[`docs/advanced/porting-notes/donut.zh-CN.md`](../../docs/advanced/porting-notes/donut.zh-CN.md)。
每个 `.patch` 都是针对所列仓库项目的 `git diff`，在该项目根目录下应用：

```sh
cd aosp-donut/system/core && git apply ../../patches/donut/system-core.patch
```

| Patch | 项目 | 内容 |
| --- | --- | --- |
| `system-core.patch` | `system/core` | init：cooper STL 卷扫描打通（`do_insmod_inner`）；adb：拆分管道实现的 shell（此 bionic 上没有 `socketpair()`） |
| `frameworks-base.patch` | `frameworks/base` | `preloaded-classes`：去掉专有的 `com.google.common.*`/`masf.*`（修复 zygote 崩溃循环）；`DatabaseHelper`：预置 `device_provisioned`（修复 HOME 键） |
| `bootable-recovery.patch` | `bootable/recovery` | updater：接受 API 3、裸块 `write_raw_image` 回退方案、`run_program` 向后移植 |
| `hardware-libhardware_legacy.patch` | `hardware/libhardware_legacy` | `wifi.c`：AR6003/ath6kl 驱动加载（`WIFI_DRIVER_*`） |
| `external-wpa_supplicant.patch` | `external/wpa_supplicant` | 面向 ath6kl 栈的 wext/cfg80211 兼容性调整 |
| `packages-providers-CalendarProvider.patch` | `packages/providers/CalendarProvider` | 测试需链接 `vendor/googlelogin` 桩 |
| `mkbootimg-pagesize.patch` | `system/core` | mkbootimg：`--pagesize` + 8K 填充缓冲（2048 的硬编码会损坏 4096 输出） |
| `files/vendor/googlelogin/` | 新增树 `vendor/googlelogin` | 专有 `com.google.android.googlelogin` 的极小桩，`CalendarProvider/tests` 需要它（复制进 `aosp-donut/vendor/`） |

说明：
- `files/` 是以 AOSP 根为基准的纯复制 overlay：
  `cp -a files/vendor aosp-donut/vendor/`。
- Patch 对应的是产出经启动验证的 cooper zip 的那棵树；
  它们是纯 diff（无 commit 元数据），因此能经受重复 sync。
